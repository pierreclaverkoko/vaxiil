from __future__ import annotations

import uuid
from dataclasses import dataclass
from decimal import Decimal

from django.db.models import Sum
from django.utils import timezone

from src.apps.bookings.cancellation_models import CancellationPolicy
from src.apps.bookings.models import Booking
from src.apps.finances.services.platform_fees import reverse_platform_fee_for_booking
from src.apps.payments.models import PaymentTransaction
from src.apps.payments.services.wallet import credit_wallet


@dataclass
class RefundSummary:
    attempted: bool
    amount: Decimal | None
    currency_code: str | None
    status: str | None
    transaction_id: str | None
    reason: str
    destination: str = 'none'


def _earliest_slot_start(booking: Booking):
    slots = booking.time_slots.filter(deleted_at__isnull=True).order_by('start_time')
    first = slots.first()
    return first.start_time if first else None


def net_captured_for_booking(booking: Booking) -> tuple[Decimal, str | None]:
    """Return (net amount, currency ISO code) from succeeded payment minus refunds."""
    base = PaymentTransaction.objects.filter(
        booking=booking,
        status=PaymentTransaction.TransactionStatus.SUCCEEDED,
    )
    paid = base.filter(
        kind=PaymentTransaction.TransactionKind.PAYMENT,
    ).aggregate(t=Sum('amount'))['t'] or Decimal('0')

    refunded = base.filter(
        kind__in=(
            PaymentTransaction.TransactionKind.REFUND,
            PaymentTransaction.TransactionKind.PARTIAL_REFUND,
        )
    ).aggregate(t=Sum('amount'))['t'] or Decimal('0')

    # Wallet credits applied at checkout also reduce what is still "owed" via
    # succeeded PAYMENT rows only; wallet debits are separate. Net captured
    # remains payment minus PSP/wallet refund ledger rows on the booking.
    net = paid - refunded
    if net < 0:
        net = Decimal('0')

    ccode = None
    last_pay = (
        PaymentTransaction.objects.filter(
            booking=booking,
            status=PaymentTransaction.TransactionStatus.SUCCEEDED,
            kind=PaymentTransaction.TransactionKind.PAYMENT,
        )
        .select_related('currency')
        .order_by('-created_at')
        .first()
    )
    if last_pay:
        ccode = last_pay.currency.code
    elif booking.accepted_currency_id:
        c = getattr(booking.accepted_currency, 'currency', None)
        if c:
            ccode = c.code

    return net, ccode


def _active_policy(booking: Booking) -> CancellationPolicy | None:
    return (
        CancellationPolicy.objects.filter(
            organization_id=booking.organization_id,
            is_active=True,
            deleted_at__isnull=True,
        )
        .order_by('name')
        .first()
    )


def booking_is_paid(booking: Booking) -> bool:
    """True when net captured payments cover the booking total."""
    net, _ = net_captured_for_booking(booking)
    return net >= (booking.total_price or Decimal('0'))


def refund_for_booking_cancellation(
    booking: Booking,
    *,
    reason: str = '',
    initiated_by=None,
    full_refund: bool = False,
    idempotency_suffix: str = '',
) -> RefundSummary:
    """
    Credit the customer's refund wallet for the policy-calculated refund amount.

    Creates a succeeded refund PaymentTransaction (no PSP call) so net captured
    drops, and posts an idempotent wallet credit the user can reuse later.

    When full_refund=True (reject / reschedule decline), always credit 100% of net.
    """
    net, currency_code = net_captured_for_booking(booking)
    if net <= 0 or not currency_code:
        return RefundSummary(
            attempted=False,
            amount=None,
            currency_code=currency_code,
            status=None,
            transaction_id=None,
            reason='no_captured_payment',
            destination='none',
        )

    if full_refund:
        pct = Decimal('100')
    else:
        slot_start = _earliest_slot_start(booking)
        now = timezone.now()
        policy = _active_policy(booking)
        if slot_start:
            hours_before = (slot_start - now).total_seconds() / 3600.0
        else:
            hours_before = 99999.0
        if policy:
            pct = Decimal(str(policy.get_refund_percentage(hours_before)))
        else:
            pct = Decimal('100')

    refund_amount = (net * pct / Decimal('100')).quantize(Decimal('0.01'))
    if refund_amount <= 0:
        return RefundSummary(
            attempted=False,
            amount=Decimal('0'),
            currency_code=currency_code,
            status='skipped',
            transaction_id=None,
            reason='policy_zero_refund',
            destination='none',
        )

    last_capture = (
        PaymentTransaction.objects.filter(
            booking=booking,
            status=PaymentTransaction.TransactionStatus.SUCCEEDED,
            kind=PaymentTransaction.TransactionKind.PAYMENT,
        )
        .select_related('payment_provider', 'currency')
        .order_by('-created_at')
        .first()
    )

    if not last_capture:
        return RefundSummary(
            attempted=False,
            amount=None,
            currency_code=currency_code,
            status=None,
            transaction_id=None,
            reason='no_payment_transaction',
            destination='none',
        )

    provider = last_capture.payment_provider
    currency = last_capture.currency
    suffix = f'-{idempotency_suffix}' if idempotency_suffix else ''
    idempotency_key = f'wallet-refund-{booking.pk}{suffix}'
    wallet_credit_key = f'wallet-credit-{booking.pk}{suffix}'

    existing = PaymentTransaction.objects.filter(
        payment_provider=provider,
        idempotency_key=idempotency_key[:128],
    ).first()
    if existing:
        return RefundSummary(
            attempted=True,
            amount=existing.amount,
            currency_code=currency.code,
            status=(
                'succeeded'
                if existing.status == PaymentTransaction.TransactionStatus.SUCCEEDED
                else 'failed'
            ),
            transaction_id=str(existing.pk),
            reason=reason or '',
            destination='wallet',
        )

    pt = PaymentTransaction.objects.create(
        booking=booking,
        payment_provider=provider,
        user=booking.user,
        initiated_by=initiated_by,
        amount=refund_amount,
        currency=currency,
        kind=PaymentTransaction.TransactionKind.REFUND
        if refund_amount >= net
        else PaymentTransaction.TransactionKind.PARTIAL_REFUND,
        status=PaymentTransaction.TransactionStatus.SUCCEEDED,
        idempotency_key=idempotency_key[:128],
        client_reference=str(booking.pk),
        provider_response_code='wallet_credit',
        provider_response_body={'destination': 'wallet'},
    )

    reverse_platform_fee_for_booking(
        booking,
        refund_amount=refund_amount,
        net_before_refund=net,
    )

    credit_wallet(
        user=booking.user,
        currency=currency,
        amount=refund_amount,
        booking=booking,
        idempotency_key=wallet_credit_key[:128],
        note=reason or 'Cancellation credit',
    )

    return RefundSummary(
        attempted=True,
        amount=refund_amount,
        currency_code=currency.code,
        status='succeeded',
        transaction_id=str(pt.pk),
        reason=reason or '',
        destination='wallet',
    )
