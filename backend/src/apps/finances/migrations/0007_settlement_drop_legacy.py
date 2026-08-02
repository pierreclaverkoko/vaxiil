# Drop legacy settlement columns after data migration

import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('finances', '0006_payment_catalog_settlement'),
        ('payments', '0006_payment_connector_method'),
    ]

    operations = [
        migrations.RemoveIndex(
            model_name='settlementaccount',
            name='settlement__method_8ccd8b_idx',
        ),
        migrations.RemoveField(
            model_name='settlementaccount',
            name='account_holder_name',
        ),
        migrations.RemoveField(
            model_name='settlementaccount',
            name='bank_country',
        ),
        migrations.RemoveField(
            model_name='settlementaccount',
            name='bank_name',
        ),
        migrations.RemoveField(
            model_name='settlementaccount',
            name='bic_swift',
        ),
        migrations.RemoveField(
            model_name='settlementaccount',
            name='iban',
        ),
        migrations.RemoveField(
            model_name='settlementaccount',
            name='interac_email',
        ),
        migrations.RemoveField(
            model_name='settlementaccount',
            name='method_legacy',
        ),
        migrations.RemoveField(
            model_name='settlementaccount',
            name='mobile_money_country',
        ),
        migrations.RemoveField(
            model_name='settlementaccount',
            name='phone_number',
        ),
        migrations.RemoveField(
            model_name='settlementrequest',
            name='method_legacy',
        ),
        migrations.AlterField(
            model_name='settlementaccount',
            name='method',
            field=models.ForeignKey(
                on_delete=django.db.models.deletion.PROTECT,
                related_name='settlement_accounts',
                to='payments.paymentmethod',
            ),
        ),
        migrations.AlterField(
            model_name='settlementaccount',
            name='account_identifier',
            field=models.CharField(
                help_text='Primary rail id: IBAN, account number, phone, email, …',
                max_length=255,
            ),
        ),
        migrations.AlterField(
            model_name='settlementrequest',
            name='method_code',
            field=models.CharField(
                help_text='PaymentMethod.code snapshot at request time.',
                max_length=64,
            ),
        ),
    ]
