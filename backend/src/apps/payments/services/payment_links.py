from __future__ import annotations

import uuid
from dataclasses import dataclass
from decimal import Decimal

from django.db import transaction
from django.utils.translation import gettext
from rest_framework.exceptions import PermissionDenied, ValidationError

from src.apps.bookings.models import Booking
from src.apps.payments.adapters import get_adapter_for_provider
from src.apps.payments.catalog import PaymentMethod
from src.apps.payments.models import PaymentProvider, PaymentTransaction
from src.apps.payments.services.refunds import net_captured_for_booking
from src.apps.payments.services.wallet import debit_wallet, wallet_balance_for
@dataclass
class CollectPaymentResult:
    merchant_reference: str | None
    transaction_id: str | None
    amount_charged: Decimal
    wallet_applied: Decimal
    fully_paid: bool
    status: str | None = None
    message: str = ''


@dataclass
class FundWalletResult:
    merchant_reference: str
    transaction_id: str
    amount: Decimal
    status: str
    message: str = ''


def _default_provider() -> PaymentProvider:
    """Default collection provider (MM Aggregator)."""
    provider = PaymentProvider.objects.filter(
        code='mm_aggregator',
        is_active=True,
    ).first()
    if provider is None:
        raise ValidationError(
            {
                'payment_provider': gettext(
                    'Secure payment is not configured. '
                    'Please try again later or contact support.'
                )
            }
        )
    return provider


def _wallet_provider() -> PaymentProvider:
    provider, _created = PaymentProvider.objects.get_or_create(
        code='wallet',
        defaults={
            'provider_type': PaymentProvider.ProviderType.WALLET,
            'display_name': 'Store credit',
            'is_active': True,
        },
    )
    return provider


def _currency_for_booking(booking: Booking):
    if booking.accepted_currency_id and booking.accepted_currency:
        return booking.accepted_currency.currency
    if booking.service_id and getattr(booking.service, 'accepted_currency', None):
        return booking.service.accepted_currency.currency
    raise ValidationError({'currency': gettext('Booking has no accepted currency.')})


def _resolve_collect_method(
    *,
    payment_method_id: str | None,
    operation: str,
) -> PaymentMethod:
    if not payment_method_id:
        raise ValidationError(
            {'payment_method_id': gettext('Payment method is required.')}
        )
    method = (
        PaymentMethod.objects.filter(
            pk=payment_method_id,
            is_active=True,
            deleted_at__isnull=True,
        )
        .select_related('connector')
        .first()
    )
    if method is None:
        raise ValidationError(
            {'payment_method_id': gettext('Unknown or inactive payment method.')}
        )
    if not method.supports_operation(operation):
        raise ValidationError(
            {
                'payment_method_id': gettext(
                    'This payment method does not support this operation.'
                )
            }
        )
    provider_code = (method.config or {}).get('provider_code')
    if not provider_code:
        raise ValidationError(
            {
                'payment_method_id': gettext(
                    'This payment method is not configured for collection.'
                )
            }
        )
    return method


def collect_for_booking(
    *,
    booking: Booking,
    user,
    payment_method_id: str | None,
    account_identifier: str,
    account_name: str | None = None,
    details: dict | None = None,
    apply_wallet: bool = False,
    wallet_amount: Decimal | None = None,
    callback_url: str | None = None,
    request=None,
) -> CollectPaymentResult:
    from src.apps.core.request_meta import (
        PAYMENT_LINK_CREATE,
        PAYMENT_WALLET_APPLY,
        create_audit_event,
    )

    if booking.user_id != user.id:
        raise PermissionDenied(gettext('You can only pay for your own bookings.'))

    if booking.status not in (
        Booking.BookingStatus.REQUESTED,
        Booking.BookingStatus.DRAFT,
        Booking.BookingStatus.RESCHEDULED,
    ):
        raise ValidationError(
            {
                'status': gettext(
                    'Only unpaid requested or rescheduled bookings can be paid.'
                )
            }
        )

    net, _currency_code = net_captured_for_booking(booking)
    currency = _currency_for_booking(booking)

    from src.apps.finances.services.inscription import inscription_fee_due_for_user

    inscription_due = inscription_fee_due_for_user(user=user, currency=currency)
    if booking.inscription_fee_amount != inscription_due:
        booking.inscription_fee_amount = inscription_due
        booking.save(update_fields=['inscription_fee_amount', 'updated_at'])

    amount_due = (booking.total_price + inscription_due) - net
    if net >= (booking.total_price + inscription_due):
        raise ValidationError({'payment': gettext('Booking is already paid.')})
    if amount_due <= 0:
        raise ValidationError({'amount': gettext('Nothing left to pay.')})

    wallet_applied = Decimal('0')

    with transaction.atomic():
        if apply_wallet or (wallet_amount is not None and wallet_amount > 0):
            available = wallet_balance_for(user=user, currency=currency)
            if wallet_amount is None:
                to_apply = min(available, amount_due)
            else:
                to_apply = Decimal(wallet_amount).quantize(Decimal('0.01'))
                if to_apply > available:
                    raise ValidationError(
                        {'wallet_amount': gettext('Insufficient store credit.')}
                    )
                if to_apply > amount_due:
                    to_apply = amount_due
            if to_apply > 0:
                debit_wallet(
                    user=user,
                    currency=currency,
                    amount=to_apply,
                    booking=booking,
                    idempotency_key=f'wallet-apply-{booking.pk}-{uuid.uuid4().hex[:8]}',
                    note='Applied to booking payment',
                )
                wallet_provider = _wallet_provider()
                wallet_audit = create_audit_event(
                    request, user=user, action=PAYMENT_WALLET_APPLY
                )
                PaymentTransaction.objects.create(
                    booking=booking,
                    payment_provider=wallet_provider,
                    user=user,
                    amount=to_apply,
                    currency=currency,
                    kind=PaymentTransaction.TransactionKind.PAYMENT,
                    status=PaymentTransaction.TransactionStatus.SUCCEEDED,
                    client_reference=f'wallet_{booking.id}_{uuid.uuid4().hex[:10]}',
                    idempotency_key=f'wallet_pay_{booking.id}_{uuid.uuid4().hex[:10]}',
                    provider_response_code='wallet_applied',
                    provider_response_body={'destination': 'wallet'},
                    audit_event=wallet_audit,
                )
                wallet_applied = to_apply
                amount_due = amount_due - to_apply

        if amount_due <= 0:
            from src.apps.finances.services.inscription import (
                finalize_booking_platform_charges,
            )
            from src.apps.finances.services.platform_fees import (
                accrue_platform_fee_for_booking,
            )

            accrue_platform_fee_for_booking(booking)
            finalize_booking_platform_charges(booking=booking)
            return CollectPaymentResult(
                merchant_reference=None,
                transaction_id=None,
                amount_charged=Decimal('0'),
                wallet_applied=wallet_applied,
                fully_paid=True,
                status='succeeded',
            )

        method = _resolve_collect_method(
            payment_method_id=payment_method_id,
            operation=PaymentMethod.Operation.COLLECT,
        )
        phone = (account_identifier or '').strip()
        if not phone:
            raise ValidationError(
                {
                    'account_identifier': gettext(
                        'Phone number or account identifier is required.'
                    )
                }
            )
        if method.account_regex:
            import re

            try:
                if not re.match(method.account_regex, phone):
                    raise ValidationError(
                        {
                            'account_identifier': gettext(
                                'Account identifier format is invalid for this method.'
                            )
                        }
                    )
            except re.error:
                pass

        provider_code = str((method.config or {}).get('provider_code'))
        provider = _default_provider()
        adapter = get_adapter_for_provider(provider)

        merchant_reference = f'bk_{booking.id}_{uuid.uuid4().hex[:10]}'
        link_audit = create_audit_event(
            request, user=user, action=PAYMENT_LINK_CREATE
        )
        txn = PaymentTransaction.objects.create(
            booking=booking,
            purpose=PaymentTransaction.Purpose.BOOKING,
            payment_provider=provider,
            user=user,
            amount=amount_due,
            currency=currency,
            kind=PaymentTransaction.TransactionKind.PAYMENT,
            status=PaymentTransaction.TransactionStatus.PENDING,
            client_reference=merchant_reference,
            idempotency_key=f'collect_{merchant_reference}',
            provider_request_payload={
                'amount': str(amount_due),
                'currency': currency.code,
                'merchant_reference': merchant_reference,
                'wallet_applied': str(wallet_applied),
                'provider_code': provider_code,
                'customer_phone': phone,
                'payment_method_id': str(method.pk),
                'account_name': account_name or '',
                'details': details or {},
            },
            audit_event=link_audit,
        )

        result = adapter.collect(
            amount=Decimal(amount_due),
            currency_code=currency.code,
            merchant_reference=merchant_reference,
            provider_code=provider_code,
            customer_phone=phone,
            customer_name=account_name,
            callback_url=callback_url,
            metadata={
                'booking_id': str(booking.id),
                'payment_method_code': method.code,
            },
        )

        if not result.success:
            txn.status = PaymentTransaction.TransactionStatus.FAILED
            txn.provider_response_body = result.response_body
            txn.provider_response_code = result.status or 'failed'
            txn.save(
                update_fields=[
                    'status',
                    'provider_response_body',
                    'provider_response_code',
                    'updated_at',
                ]
            )
            raise ValidationError(
                {
                    'payment': result.message
                    or gettext('Payment could not be started. Please try again.')
                }
            )

        txn.provider_reference = (
            result.provider_reference or result.internal_reference
        )
        txn.provider_response_body = result.response_body
        txn.provider_response_code = result.status or 'created'
        txn.status = PaymentTransaction.TransactionStatus.PROCESSING
        txn.save(
            update_fields=[
                'provider_reference',
                'provider_response_body',
                'provider_response_code',
                'status',
                'updated_at',
            ]
        )

        immediate_success = (not result.pending) and result.status.upper() in (
            'SUCCESS',
            'SUCCEEDED',
            'COMPLETED',
        )

    if immediate_success:
        from src.apps.payments.services.webhooks import apply_payment_outcome

        apply_payment_outcome(
            merchant_reference=merchant_reference,
            succeeded=True,
            webhook_payload=result.response_body,
        )
        txn.refresh_from_db()

    return CollectPaymentResult(
        merchant_reference=merchant_reference,
        transaction_id=str(txn.id),
        amount_charged=amount_due,
        wallet_applied=wallet_applied,
        fully_paid=False,
        status=txn.status,
        message=result.message,
    )


def fund_wallet(
    *,
    user,
    amount: Decimal,
    currency_code: str,
    payment_method_id: str | None,
    account_identifier: str,
    account_name: str | None = None,
    details: dict | None = None,
    callback_url: str | None = None,
    request=None,
) -> FundWalletResult:
    from src.apps.core.request_meta import PAYMENT_TOPUP_CREATE, create_audit_event
    from src.apps.finances.models import Currency

    amount = Decimal(amount).quantize(Decimal('0.01'))
    if amount <= 0:
        raise ValidationError({'amount': gettext('Top-up amount must be positive.')})

    currency = Currency.objects.filter(
        code=currency_code.upper(), is_active=True
    ).first()
    if currency is None:
        raise ValidationError(
            {'currency_code': gettext('Unknown or inactive currency.')}
        )

    method = _resolve_collect_method(
        payment_method_id=payment_method_id,
        operation=PaymentMethod.Operation.WALLET_FUND,
    )
    phone = (account_identifier or '').strip()
    if not phone:
        raise ValidationError(
            {
                'account_identifier': gettext(
                    'Phone number or account identifier is required.'
                )
            }
        )
    if method.account_regex:
        import re

        try:
            if not re.match(method.account_regex, phone):
                raise ValidationError(
                    {
                        'account_identifier': gettext(
                            'Account identifier format is invalid for this method.'
                        )
                    }
                )
        except re.error:
            pass

    provider_code = str((method.config or {}).get('provider_code'))
    provider = _default_provider()
    adapter = get_adapter_for_provider(provider)

    merchant_reference = f'wt_{user.id}_{uuid.uuid4().hex[:10]}'

    with transaction.atomic():
        topup_audit = create_audit_event(
            request, user=user, action=PAYMENT_TOPUP_CREATE
        )
        txn = PaymentTransaction.objects.create(
            booking=None,
            purpose=PaymentTransaction.Purpose.WALLET_TOP_UP,
            payment_provider=provider,
            user=user,
            amount=amount,
            currency=currency,
            kind=PaymentTransaction.TransactionKind.PAYMENT,
            status=PaymentTransaction.TransactionStatus.PENDING,
            client_reference=merchant_reference,
            idempotency_key=f'topup_{merchant_reference}',
            provider_request_payload={
                'amount': str(amount),
                'currency': currency.code,
                'merchant_reference': merchant_reference,
                'purpose': 'wallet_top_up',
                'provider_code': provider_code,
                'customer_phone': phone,
                'payment_method_id': str(method.pk),
                'account_name': account_name or '',
                'details': details or {},
            },
            audit_event=topup_audit,
        )

        result = adapter.collect(
            amount=amount,
            currency_code=currency.code,
            merchant_reference=merchant_reference,
            provider_code=provider_code,
            customer_phone=phone,
            customer_name=account_name,
            callback_url=callback_url,
            metadata={
                'user_id': str(user.id),
                'purpose': 'wallet_top_up',
                'payment_method_code': method.code,
            },
        )

        if not result.success:
            txn.status = PaymentTransaction.TransactionStatus.FAILED
            txn.provider_response_body = result.response_body
            txn.provider_response_code = result.status or 'failed'
            txn.save(
                update_fields=[
                    'status',
                    'provider_response_body',
                    'provider_response_code',
                    'updated_at',
                ]
            )
            raise ValidationError(
                {
                    'payment': result.message
                    or gettext('Top-up could not be started. Please try again.')
                }
            )

        txn.provider_reference = (
            result.provider_reference or result.internal_reference
        )
        txn.provider_response_body = result.response_body
        txn.provider_response_code = result.status or 'created'
        txn.status = PaymentTransaction.TransactionStatus.PROCESSING
        txn.save(
            update_fields=[
                'provider_reference',
                'provider_response_body',
                'provider_response_code',
                'status',
                'updated_at',
            ]
        )

    return FundWalletResult(
        merchant_reference=merchant_reference,
        transaction_id=str(txn.id),
        amount=amount,
        status=txn.status,
        message=result.message,
    )


# Backwards-compatible aliases for imports during migration of callers.
CreatePaymentLinkResult = CollectPaymentResult
CreateWalletTopUpResult = FundWalletResult


def create_payment_link_for_booking(**kwargs):
    """Deprecated name — redirects to collect_for_booking."""
    return collect_for_booking(**kwargs)


def create_wallet_top_up_link(**kwargs):
    """Deprecated name — redirects to fund_wallet."""
    return fund_wallet(**kwargs)
