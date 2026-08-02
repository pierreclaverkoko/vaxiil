"""Settlement account validation, settings, and request lifecycle."""

from __future__ import annotations

import re
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
from src.apps.payments.catalog import PaymentMethod


# Fallback destination fields by method_type when config.destination_fields is empty.
_TYPE_DESTINATION_FIELDS = {
    PaymentMethod.MethodType.BANK: ['account_identifier', 'account_name'],
    PaymentMethod.MethodType.MOBILE_MONEY: ['account_identifier'],
    PaymentMethod.MethodType.FINTECH: ['account_identifier'],
    PaymentMethod.MethodType.CRYPTO: ['account_identifier'],
    PaymentMethod.MethodType.OTHER: ['account_identifier'],
}


def destination_fields_for_method(method: PaymentMethod) -> list[str]:
    configured = (method.config or {}).get('destination_fields')
    if isinstance(configured, list) and configured:
        return [str(f) for f in configured]
    return list(
        _TYPE_DESTINATION_FIELDS.get(
            method.method_type,
            ['account_identifier'],
        )
    )


def validate_settlement_account_fields(*, method: PaymentMethod, data: dict) -> None:
    if not method.is_active:
        raise ValidationError({'method': _('This payment method is not available.')})
    if not method.supports_operation(PaymentMethod.Operation.SETTLEMENT):
        raise ValidationError(
            {'method': _('This payment method does not support settlement.')}
        )

    identifier = (data.get('account_identifier') or '').strip()
    account_name = (data.get('account_name') or '').strip()
    details = data.get('details') if isinstance(data.get('details'), dict) else {}

    fields = destination_fields_for_method(method)
    # Map logical field names: iban/phone/email → account_identifier; holder → account_name
    for field in fields:
        if field in (
            'iban',
            'phone_number',
            'interac_email',
            'account_number',
            'account_identifier',
        ):
            if not identifier:
                raise ValidationError(
                    {
                        'account_identifier': _(
                            'Account identifier is required for this method.'
                        )
                    }
                )
        elif field in ('account_holder_name', 'account_name', 'destination_name'):
            if not account_name:
                raise ValidationError(
                    {'account_name': _('Account name is required for this method.')}
                )
        else:
            # Extra keys live in details (e.g. bic_swift)
            if field not in details or not str(details.get(field) or '').strip():
                # bic_swift often optional — only require if listed and not optional_fields
                optional = set((method.config or {}).get('optional_fields') or [])
                if field not in optional:
                    raise ValidationError(
                        {
                            'details': _(
                                'Missing required field: %(field)s.'
                            )
                            % {'field': field}
                        }
                    )

    if method.account_regex and identifier:
        try:
            if not re.match(method.account_regex, identifier):
                raise ValidationError(
                    {
                        'account_identifier': _(
                            'Account identifier format is invalid for this method.'
                        )
                    }
                )
        except re.error:
            pass


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
    method = account.method
    logo_url = None
    if method.logo:
        try:
            logo_url = method.logo.url
        except ValueError:
            logo_url = None
    return {
        'method_id': str(method.pk),
        'method_code': method.code,
        'method_name': method.name,
        'method_type': method.method_type,
        'connector_code': method.connector.code if method.connector_id else None,
        'logo_url': logo_url,
        'label': account.label,
        'account_identifier': account.account_identifier,
        'account_name': account.account_name,
        'details': account.details or {},
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
        method_code=account.method.code,
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
