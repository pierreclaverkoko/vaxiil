from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal

from django.db.models import Q, Sum
from django.utils import timezone
from django.utils.translation import gettext as _

from src.apps.bookings.models import Booking
from src.apps.finances.models import OrganizationRevenueLedger
from src.apps.finances.services.inscription import credit_org_revenue
from src.apps.payments.models import PaymentTransaction
from src.apps.payments.services.wallet import credit_wallet

TWOPLACES = Decimal('0.01')
FULL_REFUND_HOURS = Decimal('24')
LATE_CLIENT_REFUND_PCT = Decimal('50')
# Of the retained penalty (100 - LATE_CLIENT_REFUND_PCT): 80% merchant, 20% platform.
LATE_PENALTY_PLATFORM_SHARE_PCT = Decimal('20')

_REFUND_STATUSES = (
    PaymentTransaction.TransactionStatus.SUCCEEDED,
    PaymentTransaction.TransactionStatus.REFUNDED,
)


@dataclass
class RefundSummary:
    attempted: bool
    amount: Decimal | None
    currency_code: str | None
    status: str | None
    transaction_id: str | None
    reason: str
    destination: str = 'none'
    penalty_applies: bool = False
    platform_penalty_amount: Decimal | None = None


def _earliest_slot_start(booking: Booking):
    slots = booking.time_slots.filter(deleted_at__isnull=True).order_by('start_time')
    first = slots.first()
    return first.start_time if first else None


def hours_until_booking_start(booking: Booking) -> float:
    """Hours until earliest slot; large number if no slot."""
    slot_start = _earliest_slot_start(booking)
    if not slot_start:
        return 99999.0
    return (slot_start - timezone.now()).total_seconds() / 3600.0


def cancellation_penalty_applies(booking: Booking) -> bool:
    """True when a client cancel would be within the late-cancel window."""
    return hours_until_booking_start(booking) < float(FULL_REFUND_HOURS)


def net_captured_for_booking(booking: Booking) -> tuple[Decimal, str | None]:
    """Return (net amount, currency ISO code) from succeeded payment minus refunds."""
    paid = PaymentTransaction.objects.filter(
        booking=booking,
        status=PaymentTransaction.TransactionStatus.SUCCEEDED,
        kind=PaymentTransaction.TransactionKind.PAYMENT,
    ).aggregate(t=Sum('amount'))['t'] or Decimal('0')

    refunded = PaymentTransaction.objects.filter(
        booking=booking,
        status__in=_REFUND_STATUSES,
        kind__in=(
            PaymentTransaction.TransactionKind.REFUND,
            PaymentTransaction.TransactionKind.PARTIAL_REFUND,
        ),
    ).aggregate(t=Sum('amount'))['t'] or Decimal('0')

    net = paid - refunded
    if net < 0:
        net = Decimal('0')

    ccode = None
    last_pay = (
        PaymentTransaction.objects.filter(
            booking=booking,
            kind=PaymentTransaction.TransactionKind.PAYMENT,
            status__in=(
                PaymentTransaction.TransactionStatus.SUCCEEDED,
                PaymentTransaction.TransactionStatus.REFUNDED,
            ),
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


def booking_has_refund_activity(booking: Booking) -> bool:
    """True when any refund ledger or refunded payment exists for the booking."""
    return PaymentTransaction.objects.filter(booking=booking).filter(
        Q(
            kind__in=(
                PaymentTransaction.TransactionKind.REFUND,
                PaymentTransaction.TransactionKind.PARTIAL_REFUND,
            ),
            status__in=_REFUND_STATUSES,
        )
        | Q(
            kind=PaymentTransaction.TransactionKind.PAYMENT,
            status=PaymentTransaction.TransactionStatus.REFUNDED,
        )
    ).exists()


def booking_is_paid(booking: Booking) -> bool:
    """True when net captured payments cover the booking total + inscription fee."""
    net, _ = net_captured_for_booking(booking)
    due = (booking.total_price or Decimal('0')) + (
        getattr(booking, 'inscription_fee_amount', None) or Decimal('0')
    )
    return net >= due


_OPEN_PAYMENT_STATUSES = (
    PaymentTransaction.TransactionStatus.PENDING,
    PaymentTransaction.TransactionStatus.PROCESSING,
)


def booking_open_payment_transaction(
    booking: Booking,
) -> PaymentTransaction | None:
    """Latest in-flight PAYMENT for this booking, or None."""
    return (
        PaymentTransaction.objects.filter(
            booking=booking,
            kind=PaymentTransaction.TransactionKind.PAYMENT,
            status__in=_OPEN_PAYMENT_STATUSES,
        )
        .order_by('-created_at')
        .first()
    )


def booking_payment_state(booking: Booking) -> str:
    """Return paid | processing | unpaid | refunded for client payment badges."""
    if booking_is_paid(booking):
        return 'paid'
    if booking_open_payment_transaction(booking) is not None:
        return 'processing'
    if booking_has_refund_activity(booking):
        return 'refunded'
    return 'unpaid'


def _refund_split(
    *,
    client_paid: Decimal,
    cancelled_by: str,
    full_refund: bool,
    hours_before: float,
) -> tuple[Decimal, Decimal, bool]:
    """
    Return (client_refund, platform_penalty_share, penalty_applies).

    Merchant / full_refund / early client: 100% to client, no platform penalty.
    Late client: 50% to client; of retained 50%, 20% → platform (debited from merchant).
    """
    if full_refund or cancelled_by == 'merchant' or hours_before >= float(FULL_REFUND_HOURS):
        return client_paid.quantize(TWOPLACES), Decimal('0.00'), False

    client_refund = (client_paid * LATE_CLIENT_REFUND_PCT / Decimal('100')).quantize(
        TWOPLACES
    )
    penalty = (client_paid - client_refund).quantize(TWOPLACES)
    platform_share = (
        penalty * LATE_PENALTY_PLATFORM_SHARE_PCT / Decimal('100')
    ).quantize(TWOPLACES)
    return client_refund, platform_share, True


def _mark_payments_refunded_if_cleared(booking: Booking) -> None:
    """When net captured is fully cleared, mark SUCCEEDED PAYMENT rows Refunded."""
    net, _ = net_captured_for_booking(booking)
    if net > 0:
        return
    PaymentTransaction.objects.filter(
        booking=booking,
        kind=PaymentTransaction.TransactionKind.PAYMENT,
        status=PaymentTransaction.TransactionStatus.SUCCEEDED,
    ).update(status=PaymentTransaction.TransactionStatus.REFUNDED)


def refund_for_booking_cancellation(
    booking: Booking,
    *,
    reason: str = '',
    initiated_by=None,
    full_refund: bool = False,
    cancelled_by: str = 'client',
    idempotency_suffix: str = '',
) -> RefundSummary:
    """
    Credit the client's refund wallet from the merchant revenue balance.

    Never reverses accrued platform fees. Late client cancels (<24h) refund 50%
    of client-paid amount; 20% of the retained half goes to the platform (debited
    from merchant revenue). Merchant / early / full_refund returns 100%.
    """
    if cancelled_by not in ('client', 'merchant'):
        cancelled_by = 'client'

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

    hours_before = hours_until_booking_start(booking)
    refund_amount, platform_penalty, penalty_applies = _refund_split(
        client_paid=net,
        cancelled_by=cancelled_by,
        full_refund=full_refund,
        hours_before=hours_before,
    )

    if refund_amount <= 0 and platform_penalty <= 0:
        return RefundSummary(
            attempted=False,
            amount=Decimal('0'),
            currency_code=currency_code,
            status='skipped',
            transaction_id=None,
            reason='policy_zero_refund',
            destination='none',
            penalty_applies=penalty_applies,
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
            penalty_applies=penalty_applies,
        )

    provider = last_capture.payment_provider
    currency = last_capture.currency
    suffix = f'-{idempotency_suffix}' if idempotency_suffix else ''
    idempotency_key = f'wallet-refund-{booking.pk}{suffix}'
    wallet_credit_key = f'wallet-credit-{booking.pk}{suffix}'
    org_debit_key = f'org-cancel-debit-{booking.pk}{suffix}'
    org_penalty_key = f'org-cancel-penalty-{booking.pk}{suffix}'

    existing = PaymentTransaction.objects.filter(
        payment_provider=provider,
        idempotency_key=idempotency_key[:128],
    ).first()
    if existing:
        status_label = 'refunded'
        if existing.status == PaymentTransaction.TransactionStatus.FAILED:
            status_label = 'failed'
        elif existing.status == PaymentTransaction.TransactionStatus.SUCCEEDED:
            status_label = 'succeeded'
        return RefundSummary(
            attempted=True,
            amount=existing.amount,
            currency_code=currency.code,
            status=status_label,
            transaction_id=str(existing.pk),
            reason=reason or '',
            destination='wallet' if refund_amount > 0 else 'none',
            penalty_applies=penalty_applies,
            platform_penalty_amount=platform_penalty if platform_penalty > 0 else None,
        )

    # Debit merchant for the client refund (allow negative float).
    if refund_amount > 0:
        credit_org_revenue(
            organization=booking.organization,
            currency=currency,
            amount=-refund_amount,
            kind=OrganizationRevenueLedger.Kind.CANCELLATION_DEBIT,
            reason=reason or str(_('Booking cancellation debit')),
            booking=booking,
            created_by=initiated_by,
            idempotency_key=org_debit_key[:128],
            allow_negative=True,
        )

    # Debit merchant for platform's share of the late-cancel penalty (not a fee reverse).
    if platform_penalty > 0:
        credit_org_revenue(
            organization=booking.organization,
            currency=currency,
            amount=-platform_penalty,
            kind=OrganizationRevenueLedger.Kind.CANCELLATION_PENALTY,
            reason=str(_('Late cancellation platform penalty')),
            booking=booking,
            created_by=initiated_by,
            idempotency_key=org_penalty_key[:128],
            allow_negative=True,
        )

    pt = None
    if refund_amount > 0:
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
            status=PaymentTransaction.TransactionStatus.REFUNDED,
            idempotency_key=idempotency_key[:128],
            client_reference=str(booking.pk),
            provider_response_code='wallet_credit',
            provider_response_body={
                'destination': 'wallet',
                'funded_by': 'merchant_revenue',
                'penalty_applies': penalty_applies,
                'platform_penalty': str(platform_penalty),
            },
        )

        credit_wallet(
            user=booking.user,
            currency=currency,
            amount=refund_amount,
            booking=booking,
            idempotency_key=wallet_credit_key[:128],
            note=reason or 'Cancellation credit',
        )
        _mark_payments_refunded_if_cleared(booking)

    return RefundSummary(
        attempted=refund_amount > 0 or platform_penalty > 0,
        amount=refund_amount if refund_amount > 0 else Decimal('0'),
        currency_code=currency.code,
        status='refunded' if refund_amount > 0 else 'succeeded',
        transaction_id=str(pt.pk) if pt else None,
        reason=reason or '',
        destination='wallet' if refund_amount > 0 else 'none',
        penalty_applies=penalty_applies,
        platform_penalty_amount=platform_penalty if platform_penalty > 0 else None,
    )
