from __future__ import annotations

from dataclasses import dataclass
from decimal import ROUND_HALF_UP, Decimal

from django.db import transaction
from django.db.models import Sum
from django.utils.translation import gettext as _

from src.apps.finances.models import (
    CategoryPlatformFee,
    PlatformFeeEntry,
    PlatformSettings,
)
from src.apps.organizations.models import OrganizationSettings

TWOPLACES = Decimal('0.01')


@dataclass(frozen=True)
class ResolvedPlatformFee:
    rate: Decimal
    source: str
    payer: str
    category_id: object | None


@dataclass(frozen=True)
class ComputedPlatformFee:
    base_price: Decimal
    rate: Decimal
    fee_amount: Decimal
    total_price: Decimal
    payer: str
    source: str
    category_id: object | None


def resolve_platform_fee(*, organization, service) -> ResolvedPlatformFee:
    """Resolve rate: org override → category override → global default."""
    settings_row = getattr(organization, 'settings', None)
    if settings_row is None:
        settings_row = OrganizationSettings.objects.filter(
            organization=organization,
            deleted_at__isnull=True,
        ).first()

    payer = OrganizationSettings.PlatformFeePayer.CLIENT
    if settings_row is not None:
        payer = settings_row.platform_fee_payer
        if settings_row.platform_fee_rate is not None:
            return ResolvedPlatformFee(
                rate=Decimal(settings_row.platform_fee_rate),
                source=PlatformFeeEntry.FeeSource.ORGANIZATION,
                payer=payer,
                category_id=_category_id(service),
            )

    category = _category(service)
    if category is not None:
        cat_fee = (
            CategoryPlatformFee.objects.filter(
                category=category,
                deleted_at__isnull=True,
            )
            .only('rate')
            .first()
        )
        if cat_fee is not None:
            return ResolvedPlatformFee(
                rate=Decimal(cat_fee.rate),
                source=PlatformFeeEntry.FeeSource.CATEGORY,
                payer=payer,
                category_id=category.pk,
            )

    global_rate = PlatformSettings.get_solo().platform_fee_rate
    return ResolvedPlatformFee(
        rate=Decimal(global_rate),
        source=PlatformFeeEntry.FeeSource.GLOBAL,
        payer=payer,
        category_id=category.pk if category is not None else None,
    )


def compute_platform_fee(*, base_price: Decimal, organization, service) -> ComputedPlatformFee:
    resolved = resolve_platform_fee(organization=organization, service=service)
    base = Decimal(base_price).quantize(TWOPLACES, rounding=ROUND_HALF_UP)
    fee_amount = (base * resolved.rate / Decimal('100')).quantize(
        TWOPLACES, rounding=ROUND_HALF_UP
    )
    if resolved.payer == OrganizationSettings.PlatformFeePayer.BUSINESS:
        total = base
    else:
        total = (base + fee_amount).quantize(TWOPLACES, rounding=ROUND_HALF_UP)
    return ComputedPlatformFee(
        base_price=base,
        rate=resolved.rate,
        fee_amount=fee_amount,
        total_price=total,
        payer=resolved.payer,
        source=resolved.source,
        category_id=resolved.category_id,
    )


def base_price_for_service(*, service, service_variant=None) -> Decimal:
    if service_variant is not None:
        return Decimal(service_variant.price)
    return Decimal(service.price_min)


def apply_platform_fee_to_booking_data(
    *,
    validated_data: dict,
    service,
    organization,
) -> dict:
    """Mutate booking create payload with server-authoritative fee fields."""
    variant = validated_data.get('service_variant')
    base = base_price_for_service(service=service, service_variant=variant)
    computed = compute_platform_fee(
        base_price=base,
        organization=organization,
        service=service,
    )
    validated_data['base_price'] = computed.base_price
    validated_data['platform_fee_rate'] = computed.rate
    validated_data['platform_fee_amount'] = computed.fee_amount
    validated_data['platform_fee_payer'] = computed.payer
    validated_data['platform_fee_source'] = computed.source
    validated_data['total_price'] = computed.total_price
    return validated_data


def _currency_for_booking(booking):
    if booking.accepted_currency_id and booking.accepted_currency.currency_id:
        return booking.accepted_currency.currency
    org = booking.organization
    if org.default_currency_id and org.default_currency.currency_id:
        return org.default_currency.currency
    return None


@transaction.atomic
def accrue_platform_fee_for_booking(booking, *, payment_transaction=None) -> PlatformFeeEntry | None:
    """Create an accrued ledger row once payment succeeds (idempotent)."""
    fee_amount = Decimal(booking.platform_fee_amount or 0)
    if fee_amount <= 0:
        return None

    existing = PlatformFeeEntry.objects.filter(
        booking=booking,
        status=PlatformFeeEntry.EntryStatus.ACCRUED,
    ).first()
    if existing:
        return existing

    currency = _currency_for_booking(booking)
    if currency is None:
        return None

    return PlatformFeeEntry.objects.create(
        booking=booking,
        organization_id=booking.organization_id,
        category_id=_category_id(booking.service) if booking.service_id else None,
        currency=currency,
        amount=fee_amount,
        rate=booking.platform_fee_rate or Decimal('0'),
        payer=booking.platform_fee_payer or PlatformFeeEntry.FeePayer.CLIENT,
        source=booking.platform_fee_source or PlatformFeeEntry.FeeSource.GLOBAL,
        status=PlatformFeeEntry.EntryStatus.ACCRUED,
        payment_transaction=payment_transaction,
    )


@transaction.atomic
def reverse_platform_fee_for_booking(
    booking,
    *,
    refund_amount: Decimal,
    net_before_refund: Decimal,
) -> PlatformFeeEntry | None:
    """Reverse platform fee pro-rata with the refund of captured payment."""
    accrued = (
        PlatformFeeEntry.objects.filter(
            booking=booking,
            status=PlatformFeeEntry.EntryStatus.ACCRUED,
        )
        .order_by('-created_at')
        .first()
    )
    if accrued is None:
        return None

    already_reversed = (
        PlatformFeeEntry.objects.filter(
            booking=booking,
            status=PlatformFeeEntry.EntryStatus.REVERSED,
        ).aggregate(total=Sum('amount'))['total']
        or Decimal('0')
    )
    remaining = accrued.amount - already_reversed
    if remaining <= 0:
        return None

    if net_before_refund <= 0:
        reverse_amount = remaining
    else:
        ratio = Decimal(refund_amount) / Decimal(net_before_refund)
        if ratio > 1:
            ratio = Decimal('1')
        reverse_amount = (remaining * ratio).quantize(TWOPLACES, rounding=ROUND_HALF_UP)

    if reverse_amount <= 0:
        return None

    return PlatformFeeEntry.objects.create(
        booking=booking,
        organization_id=accrued.organization_id,
        category_id=accrued.category_id,
        currency=accrued.currency,
        amount=reverse_amount,
        rate=accrued.rate,
        payer=accrued.payer,
        source=accrued.source,
        status=PlatformFeeEntry.EntryStatus.REVERSED,
        payment_transaction=None,
    )


def _category(service):
    sub = getattr(service, 'sub_category', None)
    if sub is None:
        return None
    return getattr(sub, 'category', None)


def _category_id(service):
    cat = _category(service)
    return cat.pk if cat is not None else None


def _payer_choice(payer: str) -> dict:
    try:
        label = OrganizationSettings.PlatformFeePayer(payer).label
    except ValueError:
        label = payer
    return {
        'value': payer,
        'title': str(label),
        'css': (
            'info'
            if payer == OrganizationSettings.PlatformFeePayer.CLIENT
            else 'warning'
        ),
    }


def _source_choice(source: str) -> dict:
    try:
        label = PlatformFeeEntry.FeeSource(source).label
    except ValueError:
        label = source
    css = {
        PlatformFeeEntry.FeeSource.GLOBAL: 'secondary',
        PlatformFeeEntry.FeeSource.CATEGORY: 'info',
        PlatformFeeEntry.FeeSource.ORGANIZATION: 'primary',
    }.get(source, 'default')
    return {'value': source, 'title': str(label), 'css': css}


def organization_fee_summary(organization) -> dict:
    """Read-only fee summary for business clients (org-level; category varies per service)."""
    settings_row = OrganizationSettings.objects.filter(
        organization=organization,
        deleted_at__isnull=True,
    ).first()
    payer = OrganizationSettings.PlatformFeePayer.CLIENT
    org_override = None
    if settings_row is not None:
        payer = settings_row.platform_fee_payer
        org_override = settings_row.platform_fee_rate

    global_rate = PlatformSettings.get_solo().platform_fee_rate
    if org_override is not None:
        source = PlatformFeeEntry.FeeSource.ORGANIZATION
        rate = Decimal(org_override)
    else:
        source = PlatformFeeEntry.FeeSource.GLOBAL
        rate = Decimal(global_rate)

    return {
        'platform_fee_rate': str(rate),
        'platform_fee_source': _source_choice(source),
        'platform_fee_payer': _payer_choice(payer),
        'has_organization_override': org_override is not None,
        'global_platform_fee_rate': str(Decimal(global_rate)),
        'organization_platform_fee_rate': (
            str(Decimal(org_override)) if org_override is not None else None
        ),
        'note': _(
            'Category-specific rates may apply when no company override is set. '
            'Platform fees are managed by VAXIIL staff.'
        ),
    }
