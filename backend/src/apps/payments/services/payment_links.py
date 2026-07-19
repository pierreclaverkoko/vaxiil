from __future__ import annotations

import uuid
from dataclasses import dataclass
from decimal import Decimal

from django.conf import settings
from django.db import transaction
from django.utils.translation import gettext
from rest_framework.exceptions import PermissionDenied, ValidationError

from src.apps.bookings.models import Booking
from src.apps.payments.adapters import get_adapter_for_provider
from src.apps.payments.models import PaymentProvider, PaymentTransaction
from src.apps.payments.services.refunds import net_captured_for_booking
from src.apps.payments.services.wallet import debit_wallet, wallet_balance_for


@dataclass
class CreatePaymentLinkResult:
    url: str | None
    merchant_reference: str | None
    transaction_id: str | None
    amount_charged: Decimal
    wallet_applied: Decimal
    fully_paid: bool


def _default_provider() -> PaymentProvider:
    """Secure checkout provider (MainMoney adapter) for payment links."""
    provider = PaymentProvider.objects.filter(
        code='mainmoney',
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
            'display_name': 'Escrow',
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


def create_payment_link_for_booking(
    *,
    booking: Booking,
    user,
    redirect_url: str | None = None,
    apply_wallet: bool = False,
    wallet_amount: Decimal | None = None,
) -> CreatePaymentLinkResult:
    if booking.user_id != user.id:
        raise PermissionDenied(gettext('You can only pay for your own bookings.'))

    if booking.status not in (
        Booking.BookingStatus.REQUESTED,
        Booking.BookingStatus.DRAFT,
    ):
        raise ValidationError(
            {'status': gettext('Only requested (unpaid) bookings can be paid.')}
        )

    net, _currency_code = net_captured_for_booking(booking)
    if net >= booking.total_price:
        raise ValidationError({'payment': gettext('Booking is already paid.')})

    amount_due = booking.total_price - net
    if amount_due <= 0:
        raise ValidationError({'amount': gettext('Nothing left to pay.')})

    currency = _currency_for_booking(booking)
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
                        {'wallet_amount': gettext('Insufficient escrow balance.')}
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
                )
                wallet_applied = to_apply
                amount_due = amount_due - to_apply

        if amount_due <= 0:
            from src.apps.finances.services.platform_fees import (
                accrue_platform_fee_for_booking,
            )

            if booking.status in (
                Booking.BookingStatus.REQUESTED,
                Booking.BookingStatus.DRAFT,
            ):
                booking.confirm()
            accrue_platform_fee_for_booking(booking)
            return CreatePaymentLinkResult(
                url=None,
                merchant_reference=None,
                transaction_id=None,
                amount_charged=Decimal('0'),
                wallet_applied=wallet_applied,
                fully_paid=True,
            )

        provider = _default_provider()
        adapter = get_adapter_for_provider(provider)

        merchant_reference = f'bk_{booking.id}_{uuid.uuid4().hex[:10]}'
        if not redirect_url:
            redirect_base = getattr(settings, 'PAYMENT_REDIRECT_BASE_URL', '').rstrip('/')
            if redirect_base:
                redirect_url = f'{redirect_base}/payment-return'

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
            idempotency_key=f'paylink_{merchant_reference}',
            provider_request_payload={
                'amount': str(amount_due),
                'currency': currency.code,
                'merchant_reference': merchant_reference,
                'wallet_applied': str(wallet_applied),
            },
        )

        result = adapter.create_payment_link(
            amount=Decimal(amount_due),
            currency_code=currency.code,
            merchant_reference=merchant_reference,
            redirect_url=redirect_url,
            title=f'Booking {booking.id}',
            description=getattr(booking.service, 'name', None) or 'Vaxiil booking',
            metadata={'booking_id': str(booking.id)},
        )

        txn.provider_reference = result.link_id or result.slug
        txn.provider_response_body = result.response_body
        txn.provider_response_code = 'created'
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

    return CreatePaymentLinkResult(
        url=result.url,
        merchant_reference=merchant_reference,
        transaction_id=str(txn.id),
        amount_charged=amount_due,
        wallet_applied=wallet_applied,
        fully_paid=False,
    )


@dataclass
class CreateWalletTopUpResult:
    url: str
    merchant_reference: str
    transaction_id: str
    amount: Decimal


def create_wallet_top_up_link(
    *,
    user,
    amount: Decimal,
    currency_code: str,
    redirect_url: str | None = None,
) -> CreateWalletTopUpResult:
    from src.apps.finances.models import Currency

    amount = Decimal(amount).quantize(Decimal('0.01'))
    if amount <= 0:
        raise ValidationError({'amount': gettext('Top-up amount must be positive.')})

    currency = Currency.objects.filter(code=currency_code.upper(), is_active=True).first()
    if currency is None:
        raise ValidationError({'currency_code': gettext('Unknown or inactive currency.')})

    provider = _default_provider()
    adapter = get_adapter_for_provider(provider)

    merchant_reference = f'wt_{user.id}_{uuid.uuid4().hex[:10]}'
    if not redirect_url:
        redirect_base = getattr(settings, 'PAYMENT_REDIRECT_BASE_URL', '').rstrip('/')
        if redirect_base:
            redirect_url = f'{redirect_base}/payment-return'

    with transaction.atomic():
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
            },
        )

        result = adapter.create_payment_link(
            amount=amount,
            currency_code=currency.code,
            merchant_reference=merchant_reference,
            redirect_url=redirect_url,
            title='Escrow top-up',
            description='Add funds to your Vaxiil escrow balance',
            metadata={'user_id': str(user.id), 'purpose': 'wallet_top_up'},
        )

        txn.provider_reference = result.link_id or result.slug
        txn.provider_response_body = result.response_body
        txn.provider_response_code = 'created'
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

    return CreateWalletTopUpResult(
        url=result.url,
        merchant_reference=merchant_reference,
        transaction_id=str(txn.id),
        amount=amount,
    )
