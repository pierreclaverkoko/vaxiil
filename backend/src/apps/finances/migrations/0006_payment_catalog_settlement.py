# Add new settlement fields + seed catalog + migrate account data

import django.db.models.deletion
from django.db import migrations, models


def seed_and_migrate_accounts(apps, schema_editor):
    PaymentConnector = apps.get_model('payments', 'PaymentConnector')
    PaymentMethod = apps.get_model('payments', 'PaymentMethod')
    Country = apps.get_model('organizations', 'Country')
    SettlementAccount = apps.get_model('finances', 'SettlementAccount')
    SettlementRequest = apps.get_model('finances', 'SettlementRequest')

    def country_by_iso(iso2):
        return Country.objects.filter(cities_country__code__iexact=iso2, is_active=True).first()

    manual, _ = PaymentConnector.objects.get_or_create(
        code='manual',
        defaults={
            'name': 'Manual / staff payout',
            'connector_type': 'M',
            'adapter_key': 'manual',
            'configuration': {},
            'is_active': True,
        },
    )
    PaymentConnector.objects.get_or_create(
        code='mm_aggregator',
        defaults={
            'name': 'MM Aggregator',
            'connector_type': 'A',
            'adapter_key': 'mm_aggregator',
            'configuration': {},
            'is_active': True,
        },
    )
    PaymentConnector.objects.get_or_create(
        code='blaaiz',
        defaults={
            'name': 'Blaaiz',
            'connector_type': 'A',
            'adapter_key': 'blaaiz',
            'configuration': {},
            'is_active': True,
        },
    )

    swift, _ = PaymentMethod.objects.get_or_create(
        code='SWIFT_IBAN',
        defaults={
            'connector': manual,
            'name': 'Bank / SWIFT IBAN',
            'method_type': 'B',
            'country': None,
            'currency': None,
            'account_regex': '',
            'config': {
                'destination_fields': ['iban', 'bic_swift', 'account_holder_name'],
                'optional_fields': ['bic_swift'],
            },
            'supported_operations': ['settlement', 'payout'],
            'is_active': True,
        },
    )
    interac, _ = PaymentMethod.objects.get_or_create(
        code='INTERAC_CA',
        defaults={
            'connector': manual,
            'name': 'Interac e-Transfer',
            'method_type': 'F',
            'country': country_by_iso('CA'),
            'currency': None,
            'account_regex': '',
            'config': {'destination_fields': ['interac_email', 'account_name']},
            'supported_operations': ['settlement', 'payout'],
            'is_active': True,
        },
    )

    momo_by_iso = {}
    for iso in (
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
    ):
        method, _ = PaymentMethod.objects.get_or_create(
            code=f'MOMO_{iso}',
            defaults={
                'connector': manual,
                'name': f'Mobile money ({iso})',
                'method_type': 'M',
                'country': country_by_iso(iso),
                'currency': None,
                'account_regex': r'^\+?[0-9]{8,15}$',
                'config': {'destination_fields': ['phone_number', 'account_name']},
                'supported_operations': ['settlement', 'payout'],
                'is_active': True,
            },
        )
        momo_by_iso[iso] = method

    momo_generic, _ = PaymentMethod.objects.get_or_create(
        code='MOMO_GENERIC',
        defaults={
            'connector': manual,
            'name': 'Mobile money',
            'method_type': 'M',
            'country': None,
            'currency': None,
            'account_regex': r'^\+?[0-9]{8,15}$',
            'config': {'destination_fields': ['phone_number', 'account_name']},
            'supported_operations': ['settlement', 'payout'],
            'is_active': True,
        },
    )

    for account in SettlementAccount.objects.all():
        old_method = account.method_legacy
        details = {}
        if old_method == 'B':
            pm = swift
            identifier = account.iban or ''
            name = account.account_holder_name or ''
            if account.bic_swift:
                details['bic_swift'] = account.bic_swift
            if account.bank_name:
                details['bank_name'] = account.bank_name
        elif old_method == 'M':
            iso = None
            if account.mobile_money_country_id:
                try:
                    iso = account.mobile_money_country.cities_country.code
                except Exception:
                    iso = None
            pm = momo_by_iso.get((iso or '').upper(), momo_generic)
            identifier = account.phone_number or ''
            name = account.account_holder_name or ''
        else:
            pm = interac
            identifier = account.interac_email or ''
            name = account.account_holder_name or ''

        account.method = pm
        account.account_identifier = identifier
        account.account_name = name
        account.details = details
        account.save(
            update_fields=[
                'method',
                'account_identifier',
                'account_name',
                'details',
            ]
        )

    for req in SettlementRequest.objects.all():
        code = {
            'B': 'SWIFT_IBAN',
            'M': 'MOMO_GENERIC',
            'I': 'INTERAC_CA',
        }.get(req.method_legacy, req.method_legacy or 'INTERAC_CA')
        if req.settlement_account_id and req.settlement_account.method_id:
            code = req.settlement_account.method.code
        req.method_code = code
        snap = dict(req.destination_snapshot or {})
        snap.setdefault('method_code', code)
        req.destination_snapshot = snap
        req.save(update_fields=['method_code', 'destination_snapshot'])


def noop_reverse(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ('finances', '0005_fees_settlement'),
        ('payments', '0006_payment_connector_method'),
        ('organizations', '0015_fees_settlement'),
    ]

    operations = [
        migrations.RenameField(
            model_name='settlementaccount',
            old_name='method',
            new_name='method_legacy',
        ),
        migrations.RenameField(
            model_name='settlementrequest',
            old_name='method',
            new_name='method_legacy',
        ),
        migrations.AddField(
            model_name='settlementaccount',
            name='account_identifier',
            field=models.CharField(
                blank=True,
                default='',
                help_text='Primary rail id: IBAN, account number, phone, email, …',
                max_length=255,
            ),
        ),
        migrations.AddField(
            model_name='settlementaccount',
            name='account_name',
            field=models.CharField(
                blank=True,
                default='',
                help_text='Account holder / destination name.',
                max_length=255,
            ),
        ),
        migrations.AddField(
            model_name='settlementaccount',
            name='details',
            field=models.JSONField(
                blank=True,
                default=dict,
                help_text='Extra destination fields (bic_swift, bank_name, …).',
            ),
        ),
        migrations.AddField(
            model_name='settlementaccount',
            name='method',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.PROTECT,
                related_name='settlement_accounts',
                to='payments.paymentmethod',
            ),
        ),
        migrations.AddField(
            model_name='settlementrequest',
            name='method_code',
            field=models.CharField(
                blank=True,
                default='',
                help_text='PaymentMethod.code snapshot at request time.',
                max_length=64,
            ),
        ),
        migrations.RunPython(seed_and_migrate_accounts, noop_reverse),
    ]
