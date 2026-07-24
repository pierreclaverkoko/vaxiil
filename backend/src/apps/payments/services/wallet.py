from __future__ import annotations

from decimal import Decimal

from django.db import transaction
from django.db.models import F, Sum
from django.utils.translation import gettext as _
from rest_framework.exceptions import ValidationError

from src.apps.finances.models import Currency
from src.apps.payments.models import RefundWallet, RefundWalletLedger


def get_or_create_wallet(*, user, currency: Currency) -> RefundWallet:
    wallet, _ = RefundWallet.objects.get_or_create(
        user=user,
        currency=currency,
        defaults={'balance': Decimal('0')},
    )
    return wallet


@transaction.atomic
def credit_wallet(
    *,
    user,
    currency: Currency,
    amount: Decimal,
    booking=None,
    idempotency_key: str = '',
    note: str = '',
    kind: str = RefundWalletLedger.Kind.CANCELLATION_CREDIT,
) -> RefundWalletLedger:
    if amount <= 0:
        raise ValidationError({'amount': _('Credit amount must be positive.')})

    if idempotency_key:
        existing = RefundWalletLedger.objects.filter(idempotency_key=idempotency_key).first()
        if existing:
            return existing

    wallet = get_or_create_wallet(user=user, currency=currency)
    wallet = RefundWallet.objects.select_for_update().get(pk=wallet.pk)
    wallet.balance = F('balance') + amount
    wallet.save(update_fields=['balance', 'updated_at'])
    wallet.refresh_from_db()

    return RefundWalletLedger.objects.create(
        wallet=wallet,
        booking=booking,
        kind=kind,
        amount=amount,
        balance_after=wallet.balance,
        idempotency_key=idempotency_key[:128] if idempotency_key else '',
        note=note[:255] if note else '',
    )


@transaction.atomic
def debit_wallet(
    *,
    user,
    currency: Currency,
    amount: Decimal,
    booking=None,
    idempotency_key: str = '',
    note: str = '',
) -> RefundWalletLedger:
    if amount <= 0:
        raise ValidationError({'amount': _('Debit amount must be positive.')})

    if idempotency_key:
        existing = RefundWalletLedger.objects.filter(idempotency_key=idempotency_key).first()
        if existing:
            return existing

    wallet = get_or_create_wallet(user=user, currency=currency)
    wallet = RefundWallet.objects.select_for_update().get(pk=wallet.pk)
    if wallet.balance < amount:
        raise ValidationError({'wallet_amount': _('Insufficient store credit.')})

    wallet.balance = F('balance') - amount
    wallet.save(update_fields=['balance', 'updated_at'])
    wallet.refresh_from_db()

    return RefundWalletLedger.objects.create(
        wallet=wallet,
        booking=booking,
        kind=RefundWalletLedger.Kind.APPLIED_TO_BOOKING,
        amount=amount,
        balance_after=wallet.balance,
        idempotency_key=idempotency_key[:128] if idempotency_key else '',
        note=note[:255] if note else '',
    )


def wallet_balance_for(*, user, currency: Currency) -> Decimal:
    wallet = RefundWallet.objects.filter(user=user, currency=currency).first()
    return wallet.balance if wallet else Decimal('0')


def wallet_summary_for(user) -> dict:
    wallets = (
        RefundWallet.objects.filter(user=user)
        .select_related('currency')
        .order_by('currency__code')
    )
    balances = [
        {
            'currency_code': w.currency.code,
            'balance': str(w.balance),
        }
        for w in wallets
    ]
    if not balances:
        # Always expose a zero balance so clients can show store credit at rest.
        default = Currency.objects.filter(code='USD', is_active=True).first()
        if default is None:
            default = Currency.objects.filter(is_active=True).order_by('code').first()
        if default is not None:
            balances = [{'currency_code': default.code, 'balance': '0.00'}]
    credit_kinds = (
        RefundWalletLedger.Kind.CANCELLATION_CREDIT,
        RefundWalletLedger.Kind.TOP_UP,
    )
    total_credited = (
        RefundWalletLedger.objects.filter(
            wallet__user=user,
            kind__in=credit_kinds,
        ).aggregate(t=Sum('amount'))['t']
        or Decimal('0')
    )
    recent = (
        RefundWalletLedger.objects.filter(wallet__user=user)
        .select_related('wallet__currency', 'booking')
        .order_by('-created_at')[:20]
    )
    ledger = [
        {
            'id': str(entry.id),
            'kind': {
                'value': entry.kind,
                'title': entry.get_kind_display(),
                'css': (
                    'success'
                    if entry.kind
                    in (
                        RefundWalletLedger.Kind.CANCELLATION_CREDIT,
                        RefundWalletLedger.Kind.TOP_UP,
                    )
                    else 'primary'
                ),
            },
            'amount': str(entry.amount),
            'currency_code': entry.wallet.currency.code,
            'balance_after': str(entry.balance_after),
            'booking_id': str(entry.booking_id) if entry.booking_id else None,
            'note': entry.note,
            'created_at': entry.created_at.isoformat(),
        }
        for entry in recent
    ]
    return {
        'balances': balances,
        'total_credited': str(total_credited),
        'ledger': ledger,
    }
