"""User inscription (verification) fee and org annual subscription / revenue wallet."""

from __future__ import annotations

from datetime import timedelta
from decimal import Decimal

from django.db import transaction
from django.db.models import F
from django.utils import timezone
from django.utils.translation import gettext as gettext_lazy_msg
from rest_framework.exceptions import ValidationError

from src.apps.finances.models import (
    OrganizationRevenueLedger,
    OrganizationRevenueWallet,
    PlatformSettings,
    UserPlatformCharge,
)
from src.apps.finances.services.fx import usd_to_currency
from src.apps.organizations.models import OrganizationSettings

TWOPLACES = Decimal('0.01')


def inscription_fee_due_for_user(*, user, currency) -> Decimal:
    """Return local-currency inscription amount if unpaid, else 0."""
    if getattr(user, 'inscription_fee_paid_at', None):
        return Decimal('0.00')
    if UserPlatformCharge.objects.filter(
        user=user,
        kind=UserPlatformCharge.Kind.INSCRIPTION,
    ).exists():
        return Decimal('0.00')
    usd = PlatformSettings.get_solo().user_inscription_fee_usd
    if usd <= 0:
        return Decimal('0.00')
    return usd_to_currency(Decimal(usd), currency)


def get_or_create_revenue_wallet(*, organization, currency) -> OrganizationRevenueWallet:
    wallet, _created = OrganizationRevenueWallet.objects.get_or_create(
        organization=organization,
        currency=currency,
        defaults={'balance': Decimal('0')},
    )
    return wallet


def available_settlement_balance(wallet: OrganizationRevenueWallet) -> Decimal:
    """Withdrawals cannot use a negative balance."""
    return max(Decimal(wallet.balance), Decimal('0'))


@transaction.atomic
def credit_org_revenue(
    *,
    organization,
    currency,
    amount: Decimal,
    kind: str,
    reason: str = '',
    booking=None,
    settlement_request=None,
    created_by=None,
    idempotency_key: str = '',
    allow_negative: bool = False,
) -> OrganizationRevenueLedger:
    """Credit (positive amount) or debit (negative amount) org revenue."""
    amount = Decimal(amount).quantize(TWOPLACES)
    if amount == 0:
        raise ValidationError({'amount': gettext_lazy_msg('Amount must be non-zero.')})

    if idempotency_key:
        existing = OrganizationRevenueLedger.objects.filter(
            idempotency_key=idempotency_key
        ).first()
        if existing:
            return existing

    wallet = get_or_create_revenue_wallet(organization=organization, currency=currency)
    wallet = OrganizationRevenueWallet.objects.select_for_update().get(pk=wallet.pk)
    new_balance = (Decimal(wallet.balance) + amount).quantize(TWOPLACES)
    if new_balance < 0 and not allow_negative:
        raise ValidationError(
            {'amount': gettext_lazy_msg('Insufficient organization revenue balance.')}
        )

    wallet.balance = F('balance') + amount
    wallet.save(update_fields=['balance', 'updated_at'])
    wallet.refresh_from_db()

    return OrganizationRevenueLedger.objects.create(
        wallet=wallet,
        kind=kind,
        amount=amount,
        balance_after=wallet.balance,
        reason=(reason or '')[:512],
        booking=booking,
        settlement_request=settlement_request,
        created_by=created_by,
        idempotency_key=idempotency_key[:128] if idempotency_key else '',
    )


def annual_subscription_due(*, organization) -> bool:
    settings_row = OrganizationSettings.objects.filter(
        organization=organization,
        deleted_at__isnull=True,
    ).first()
    if settings_row is None or settings_row.annual_fee_paid_through is None:
        return True
    return settings_row.annual_fee_paid_through < timezone.localdate()


@transaction.atomic
def mark_inscription_paid(
    *,
    user,
    currency,
    amount: Decimal,
    usd_amount: Decimal,
    booking=None,
    payment_transaction=None,
) -> UserPlatformCharge | None:
    if amount <= 0:
        return None
    if user.inscription_fee_paid_at and UserPlatformCharge.objects.filter(
        user=user,
        kind=UserPlatformCharge.Kind.INSCRIPTION,
    ).exists():
        return None

    charge, created = UserPlatformCharge.objects.get_or_create(
        user=user,
        kind=UserPlatformCharge.Kind.INSCRIPTION,
        defaults={
            'amount': amount,
            'usd_amount': usd_amount,
            'currency': currency,
            'booking': booking,
            'payment_transaction': payment_transaction,
        },
    )
    if not created:
        return charge
    user.inscription_fee_paid_at = timezone.now()
    user.save(update_fields=['inscription_fee_paid_at', 'updated_at'])
    return charge


@transaction.atomic
def apply_booking_payment_revenue(
    *,
    booking,
    payment_transaction=None,
) -> None:
    """
    After a booking payment succeeds: credit org net revenue, then charge annual
    subscription if due (may leave balance negative only for that debit).
    """
    organization = booking.organization
    currency = None
    if booking.accepted_currency_id and booking.accepted_currency:
        currency = booking.accepted_currency.currency
    if currency is None:
        return

    platform_fee = Decimal(booking.platform_fee_amount or 0)
    base = Decimal(booking.base_price or 0)
    if booking.platform_fee_payer == 'B':
        net = (base - platform_fee).quantize(TWOPLACES)
    else:
        net = base.quantize(TWOPLACES)
    if net < 0:
        net = Decimal('0.00')

    credit_org_revenue(
        organization=organization,
        currency=currency,
        amount=net,
        kind=OrganizationRevenueLedger.Kind.BOOKING_CREDIT,
        reason=gettext_lazy_msg('Booking payment credit'),
        booking=booking,
        idempotency_key=f'booking-credit-{booking.pk}',
    )

    if not annual_subscription_due(organization=organization):
        return

    usd = PlatformSettings.get_solo().business_annual_fee_usd
    if usd <= 0:
        return
    local = usd_to_currency(Decimal(usd), currency)
    credit_org_revenue(
        organization=organization,
        currency=currency,
        amount=-local,
        kind=OrganizationRevenueLedger.Kind.ANNUAL_SUBSCRIPTION,
        reason=gettext_lazy_msg('Annual business subscription'),
        booking=booking,
        idempotency_key=f'annual-sub-{booking.pk}',
        allow_negative=True,
    )
    settings_row, _created = OrganizationSettings.objects.get_or_create(
        organization=organization,
        defaults={},
    )
    today = timezone.localdate()
    through = today + timedelta(days=365)
    if (
        settings_row.annual_fee_paid_through
        and settings_row.annual_fee_paid_through >= today
    ):
        through = settings_row.annual_fee_paid_through + timedelta(days=365)
    settings_row.annual_fee_paid_through = through
    settings_row.save(update_fields=['annual_fee_paid_through'])


@transaction.atomic
def finalize_booking_platform_charges(
    *,
    booking,
    payment_transaction=None,
) -> None:
    """Mark inscription paid (if snapshotted) and apply org revenue + annual fee."""
    amount = Decimal(booking.inscription_fee_amount or 0)
    user = booking.user
    currency = None
    if booking.accepted_currency_id and booking.accepted_currency:
        currency = booking.accepted_currency.currency
    if user and amount > 0 and currency is not None:
        usd = PlatformSettings.get_solo().user_inscription_fee_usd
        mark_inscription_paid(
            user=user,
            currency=currency,
            amount=amount,
            usd_amount=Decimal(usd),
            booking=booking,
            payment_transaction=payment_transaction,
        )
    apply_booking_payment_revenue(
        booking=booking,
        payment_transaction=payment_transaction,
    )
