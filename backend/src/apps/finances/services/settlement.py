"""Settlement account validation, settings, and request lifecycle."""

from __future__ import annotations

from decimal import Decimal

from django.db import transaction
from django.utils import timezone
from django.utils.translation import gettext as _
from rest_framework.exceptions import ValidationError

from src.apps.finances.models import (
    OrganizationRevenueLedger,
    PlatformSettings,
    SettlementAccount,
    SettlementRequest,
    SettlementSettings,
)
from src.apps.finances.services.fx import usd_to_currency
from src.apps.finances.services.inscription import (
    available_settlement_balance,
    credit_org_revenue,
    get_or_create_revenue_wallet,
)

# ISO country codes accepted for mobile-money settlement destinations.
ACCEPTED_MOBILE_MONEY_COUNTRY_CODES = frozenset(
    {
        'CD',  # DRC
        'CG',
        'KE',
        'UG',
        'TZ',
        'RW',
        'BI',
        'CM',
        'CI',
        'SN',
        'GH',
        'NG',
        'ZA',
    }
)


def validate_settlement_account_fields(*, method: str, data: dict) -> None:
    if method == SettlementAccount.Method.BANK_IBAN:
        if not (data.get('iban') or '').strip():
            raise ValidationError({'iban': _('IBAN is required for bank settlement.')})
        if not (data.get('account_holder_name') or '').strip():
            raise ValidationError(
                {'account_holder_name': _('Account holder name is required.')}
            )
    elif method == SettlementAccount.Method.MOBILE_MONEY:
        if not (data.get('phone_number') or '').strip():
            raise ValidationError(
                {'phone_number': _('Phone number is required for mobile money.')}
            )
        country = data.get('mobile_money_country')
        code = getattr(country, 'code', None) or data.get('mobile_money_country_code')
        if not code or str(code).upper() not in ACCEPTED_MOBILE_MONEY_COUNTRY_CODES:
            raise ValidationError(
                {
                    'mobile_money_country': _(
                        'Mobile money is not accepted for this country.'
                    )
                }
            )
    elif method == SettlementAccount.Method.INTERAC_EMAIL:
        if not (data.get('interac_email') or '').strip():
            raise ValidationError(
                {'interac_email': _('Email is required for Interac.')}
            )
    else:
        raise ValidationError({'method': _('Unknown settlement method.')})


def minimum_settlement_amount(*, currency) -> Decimal:
    usd = PlatformSettings.get_solo().settlement_minimum_usd
    return usd_to_currency(Decimal(usd), currency)


def get_or_create_settlement_settings(*, organization, currency) -> SettlementSettings:
    settings_row = SettlementSettings.objects.filter(organization=organization).first()
    if settings_row:
        return settings_row
    floor = minimum_settlement_amount(currency=currency)
    return SettlementSettings.objects.create(
        organization=organization,
        currency=currency,
        minimum_amount=floor,
        periodicity=SettlementSettings.Periodicity.MANUAL,
    )


def _destination_snapshot(account: SettlementAccount) -> dict:
    return {
        'method': account.method,
        'label': account.label,
        'account_holder_name': account.account_holder_name,
        'iban': account.iban,
        'bic_swift': account.bic_swift,
        'bank_name': account.bank_name,
        'bank_country_id': str(account.bank_country_id)
        if account.bank_country_id
        else None,
        'phone_number': account.phone_number,
        'mobile_money_country_id': str(account.mobile_money_country_id)
        if account.mobile_money_country_id
        else None,
        'interac_email': account.interac_email,
    }


@transaction.atomic
def create_manual_settlement_request(
    *,
    organization,
    amount: Decimal,
    currency,
    account: SettlementAccount,
    requested_by,
) -> SettlementRequest:
    amount = Decimal(amount).quantize(Decimal('0.01'))
    settings_row = get_or_create_settlement_settings(
        organization=organization, currency=currency
    )
    floor = max(
        Decimal(settings_row.minimum_amount),
        minimum_settlement_amount(currency=currency),
    )
    if amount < floor:
        raise ValidationError(
            {
                'amount': _('Settlement amount must be at least %(min)s %(code)s.')
                % {'min': floor, 'code': currency.code}
            }
        )

    wallet = get_or_create_revenue_wallet(organization=organization, currency=currency)
    wallet.refresh_from_db()
    available = available_settlement_balance(wallet)
    if amount > available:
        raise ValidationError(
            {'amount': _('Amount exceeds available settlement balance.')}
        )

    req = SettlementRequest.objects.create(
        organization=organization,
        amount=amount,
        currency=currency,
        status=SettlementRequest.Status.REQUESTED,
        settlement_account=account,
        method=account.method,
        destination_snapshot=_destination_snapshot(account),
        requested_by=requested_by,
    )
    credit_org_revenue(
        organization=organization,
        currency=currency,
        amount=-amount,
        kind=OrganizationRevenueLedger.Kind.MANUAL_SETTLEMENT,
        reason=_('Manual settlement request'),
        settlement_request=req,
        created_by=requested_by,
        idempotency_key=f'settlement-hold-{req.pk}',
        allow_negative=False,
    )
    return req


@transaction.atomic
def complete_settlement_request(
    *,
    request: SettlementRequest,
    staff_user,
    confirmation_image=None,
    staff_note: str = '',
) -> SettlementRequest:
    if request.status == SettlementRequest.Status.COMPLETED:
        return request
    if request.status == SettlementRequest.Status.REJECTED:
        raise ValidationError({'status': _('Cannot complete a rejected settlement.')})

    request.status = SettlementRequest.Status.COMPLETED
    request.processed_by = staff_user
    request.processed_at = timezone.now()
    if staff_note:
        request.staff_note = staff_note
    if confirmation_image is not None:
        request.confirmation_image = confirmation_image
    request.save()
    return request


@transaction.atomic
def reject_settlement_request(
    *,
    request: SettlementRequest,
    staff_user,
    staff_note: str = '',
) -> SettlementRequest:
    if request.status == SettlementRequest.Status.COMPLETED:
        raise ValidationError({'status': _('Cannot reject a completed settlement.')})
    if request.status == SettlementRequest.Status.REJECTED:
        return request

    # Refund the hold back to org revenue.
    credit_org_revenue(
        organization=request.organization,
        currency=request.currency,
        amount=request.amount,
        kind=OrganizationRevenueLedger.Kind.SETTLEMENT_DEBIT,
        reason=_('Settlement request rejected — balance restored'),
        settlement_request=request,
        created_by=staff_user,
        idempotency_key=f'settlement-reject-{request.pk}',
        allow_negative=False,
    )
    request.status = SettlementRequest.Status.REJECTED
    request.processed_by = staff_user
    request.processed_at = timezone.now()
    if staff_note:
        request.staff_note = staff_note
    request.save()
    return request
