# Generated manually for PaymentConnector / PaymentMethod catalog

import django.contrib.postgres.fields
import django.db.models.deletion
import uuid
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('finances', '0005_fees_settlement'),
        ('organizations', '0015_fees_settlement'),
        ('payments', '0005_manual_wallet_ledger'),
    ]

    operations = [
        migrations.CreateModel(
            name='PaymentConnector',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('deleted_at', models.DateTimeField(blank=True, null=True)),
                ('code', models.SlugField(max_length=64, unique=True)),
                ('name', models.CharField(max_length=128)),
                (
                    'connector_type',
                    models.CharField(
                        choices=[
                            ('A', 'Aggregator'),
                            ('D', 'Direct'),
                            ('G', 'Gateway'),
                            ('M', 'Manual'),
                        ],
                        default='M',
                        max_length=1,
                    ),
                ),
                ('adapter_key', models.SlugField(help_text='Execution registry key (often same as code).', max_length=64)),
                ('configuration', models.JSONField(blank=True, default=dict)),
                ('is_active', models.BooleanField(default=True)),
            ],
            options={
                'db_table': 'payment_connectors',
                'ordering': ['code'],
            },
        ),
        migrations.CreateModel(
            name='PaymentMethod',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('deleted_at', models.DateTimeField(blank=True, null=True)),
                ('code', models.SlugField(max_length=64, unique=True)),
                ('name', models.CharField(max_length=200)),
                ('logo', models.ImageField(blank=True, null=True, upload_to='payment_methods/logos/')),
                (
                    'method_type',
                    models.CharField(
                        choices=[
                            ('B', 'Bank'),
                            ('M', 'Mobile money'),
                            ('F', 'Fintech'),
                            ('C', 'Crypto'),
                            ('O', 'Other'),
                        ],
                        default='O',
                        max_length=1,
                    ),
                ),
                ('account_regex', models.CharField(blank=True, max_length=255)),
                (
                    'config',
                    models.JSONField(
                        blank=True,
                        default=dict,
                        help_text='e.g. {"destination_fields": ["iban", "bic_swift", "account_holder_name"]}',
                    ),
                ),
                (
                    'supported_operations',
                    django.contrib.postgres.fields.ArrayField(
                        base_field=models.CharField(max_length=32),
                        blank=True,
                        default=list,
                        help_text='Operations this rail supports: settlement, collect, refund, wallet_fund, payout.',
                        size=None,
                    ),
                ),
                ('is_active', models.BooleanField(default=True)),
                (
                    'connector',
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.PROTECT,
                        related_name='methods',
                        to='payments.paymentconnector',
                    ),
                ),
                (
                    'country',
                    models.ForeignKey(
                        blank=True,
                        help_text='Null = globally available (e.g. SWIFT IBAN).',
                        null=True,
                        on_delete=django.db.models.deletion.PROTECT,
                        related_name='payment_methods',
                        to='organizations.country',
                    ),
                ),
                (
                    'currency',
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.PROTECT,
                        related_name='payment_methods',
                        to='finances.currency',
                    ),
                ),
            ],
            options={
                'db_table': 'payment_methods',
                'ordering': ['country', 'method_type', 'name'],
                'indexes': [
                    models.Index(fields=['code'], name='payment_met_code_idx'),
                    models.Index(fields=['method_type'], name='payment_met_type_idx'),
                    models.Index(fields=['is_active'], name='payment_met_active_idx'),
                ],
            },
        ),
    ]
