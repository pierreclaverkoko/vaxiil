"""Seed default PaymentConnector / PaymentMethod rows for settlement + collection."""

from __future__ import annotations

from src.apps.payments.catalog import PaymentConnector, PaymentMethod
from src.apps.payments.models import PaymentProvider

MOMO_COUNTRY_CODES = (
    'CD',
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
)

# Placeholder provider_code values — ops must align with mm_aggregator FinancialEntity codes.
MOMO_PROVIDER_CODES = {
    'CD': 'MPESA_CD',
    'CG': 'AIRTEL_CG',
    'KE': 'MPESA_KE',
    'UG': 'MTN_UG',
    'TZ': 'MPESA_TZ',
    'RW': 'MTN_RW',
    'BI': 'LUMICASH_BI',
    'CM': 'MTN_CM',
    'CI': 'ORANGE_CI',
    'SN': 'ORANGE_SN',
    'GH': 'MTN_GH',
    'NG': 'OPAY_NG',
    'ZA': 'OZOW_ZA',
}

SETTLEMENT_OPS = [
    PaymentMethod.Operation.SETTLEMENT,
    PaymentMethod.Operation.PAYOUT,
]

COLLECT_OPS = [
    PaymentMethod.Operation.COLLECT,
    PaymentMethod.Operation.WALLET_FUND,
    PaymentMethod.Operation.REFUND,
    PaymentMethod.Operation.SETTLEMENT,
    PaymentMethod.Operation.PAYOUT,
]


def ensure_default_payment_catalog() -> PaymentConnector:
    """Idempotent seed of manual + aggregators, collect rails, and PaymentProvider."""
    manual, _ = PaymentConnector.objects.update_or_create(
        code='manual',
        defaults={
            'name': 'Manual / staff payout',
            'connector_type': PaymentConnector.ConnectorType.MANUAL,
            'adapter_key': 'manual',
            'configuration': {},
            'is_active': True,
        },
    )
    mma, _ = PaymentConnector.objects.update_or_create(
        code='mm_aggregator',
        defaults={
            'name': 'MM Aggregator',
            'connector_type': PaymentConnector.ConnectorType.AGGREGATOR,
            'adapter_key': 'mm_aggregator',
            'configuration': {},
            'is_active': True,
        },
    )
    PaymentConnector.objects.update_or_create(
        code='blaaiz',
        defaults={
            'name': 'Blaaiz',
            'connector_type': PaymentConnector.ConnectorType.AGGREGATOR,
            'adapter_key': 'blaaiz',
            'configuration': {},
            'is_active': True,
        },
    )

    PaymentProvider.objects.update_or_create(
        code='mm_aggregator',
        defaults={
            'display_name': 'Secure payment',
            'provider_type': PaymentProvider.ProviderType.OTHER,
            'is_active': True,
            'config': {},
        },
    )
    # Legacy MainMoney — keep row but inactive so collect uses mm_aggregator.
    PaymentProvider.objects.filter(code='mainmoney').update(is_active=False)

    PaymentMethod.objects.update_or_create(
        code='SWIFT_IBAN',
        defaults={
            'connector': manual,
            'name': 'Bank / SWIFT IBAN',
            'method_type': PaymentMethod.MethodType.BANK,
            'country': None,
            'currency': None,
            'account_regex': '',
            'config': {
                'destination_fields': [
                    'iban',
                    'bic_swift',
                    'account_holder_name',
                ],
                'optional_fields': ['bic_swift'],
            },
            'supported_operations': list(SETTLEMENT_OPS),
            'is_active': True,
        },
    )
    PaymentMethod.objects.update_or_create(
        code='INTERAC_CA',
        defaults={
            'connector': manual,
            'name': 'Interac e-Transfer',
            'method_type': PaymentMethod.MethodType.FINTECH,
            'country': _country_by_iso2('CA'),
            'currency': None,
            'account_regex': '',
            'config': {'destination_fields': ['interac_email', 'account_name']},
            'supported_operations': list(SETTLEMENT_OPS),
            'is_active': True,
        },
    )

    for iso in MOMO_COUNTRY_CODES:
        country = _country_by_iso2(iso)
        provider_code = MOMO_PROVIDER_CODES.get(iso, f'MOMO_{iso}')
        PaymentMethod.objects.update_or_create(
            code=f'MOMO_{iso}',
            defaults={
                'connector': mma,
                'name': f'Mobile money ({iso})',
                'method_type': PaymentMethod.MethodType.MOBILE_MONEY,
                'country': country,
                'currency': None,
                'account_regex': r'^\+?[0-9]{8,15}$',
                'config': {
                    'destination_fields': ['phone_number', 'account_name'],
                    'optional_fields': ['account_name'],
                    'provider_code': provider_code,
                },
                'supported_operations': list(COLLECT_OPS),
                'is_active': True,
            },
        )

    return manual


def _country_by_iso2(iso2: str):
    from src.apps.organizations.models import Country

    return (
        Country.objects.filter(cities_country__code__iexact=iso2, is_active=True)
        .select_related('cities_country')
        .first()
    )
