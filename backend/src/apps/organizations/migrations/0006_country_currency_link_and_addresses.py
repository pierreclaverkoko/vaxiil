# Generated manually for Country, CountryAcceptedCurrency, OrganizationAddress

import uuid

import django.db.models.deletion
from django.db import migrations, models


def seed_usd_and_us(apps, schema_editor):
    Currency = apps.get_model('finances', 'Currency')
    Country = apps.get_model('organizations', 'Country')
    CountryAcceptedCurrency = apps.get_model('organizations', 'CountryAcceptedCurrency')
    usd, _ = Currency.objects.get_or_create(
        code='USD',
        defaults={
            'symbol': '$',
            'name': 'US Dollar',
            'numeric_code': '840',
            'minor_units': 2,
            'is_active': True,
        },
    )
    us, _ = Country.objects.get_or_create(
        iso_code2='CD',
        defaults={
            'iso_code3': 'COD',
            'name': 'Congo Democratic Republic',
            'flag': '',
            'is_active': True,
        },
    )
    if not CountryAcceptedCurrency.objects.filter(country=us, currency=usd).exists():
        CountryAcceptedCurrency.objects.create(
            country=us,
            currency=usd,
            is_active=True,
            is_default=True,
        )


def assign_org_country_and_default(apps, schema_editor):
    Organization = apps.get_model('organizations', 'Organization')
    Country = apps.get_model('organizations', 'Country')
    CountryAcceptedCurrency = apps.get_model('organizations', 'CountryAcceptedCurrency')
    drc = Country.objects.filter(iso_code2='CD').first()
    cac = CountryAcceptedCurrency.objects.filter(
        country=drc, is_default=True, deleted_at__isnull=True
    ).first()
    if drc and cac:
        Organization.objects.filter(country__isnull=True).update(
            country_id=drc.id,
            default_currency_id=cac.id,
        )


def copy_addresses(apps, schema_editor):
    Organization = apps.get_model('organizations', 'Organization')
    OrganizationAddress = apps.get_model('organizations', 'OrganizationAddress')
    Country = apps.get_model('organizations', 'Country')
    us = Country.objects.filter(iso_code2='US').first()
    for org in Organization.objects.all():
        OrganizationAddress.objects.create(
            organization_id=org.id,
            address=org.address,
            city=org.city,
            postal_code=org.postal_code,
            country_text=org.country_legacy or '',
            country_id=us.id if us else None,
            latitude=org.latitude,
            longitude=org.longitude,
            label='',
            is_primary=True,
        )


class Migration(migrations.Migration):

    dependencies = [
        ('finances', '0001_initial'),
        ('organizations', '0005_organization_kyb_submitted_at'),
    ]

    operations = [
        migrations.CreateModel(
            name='Country',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('deleted_at', models.DateTimeField(blank=True, null=True)),
                ('iso_code2', models.CharField(max_length=2, unique=True)),
                ('iso_code3', models.CharField(max_length=3, unique=True)),
                ('name', models.CharField(max_length=128)),
                ('flag', models.URLField(blank=True)),
                ('is_active', models.BooleanField(default=True)),
            ],
            options={
                'db_table': 'countries',
                'ordering': ['name'],
            },
        ),
        migrations.CreateModel(
            name='CountryAcceptedCurrency',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('deleted_at', models.DateTimeField(blank=True, null=True)),
                ('is_active', models.BooleanField(default=True)),
                ('is_default', models.BooleanField(default=False)),
                (
                    'country',
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name='accepted_currencies',
                        to='organizations.country',
                    ),
                ),
                (
                    'currency',
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.PROTECT,
                        related_name='country_acceptances',
                        to='finances.currency',
                    ),
                ),
            ],
            options={
                'db_table': 'country_accepted_currencies',
            },
        ),
        migrations.AddIndex(
            model_name='country',
            index=models.Index(fields=['iso_code2'], name='countries_iso_cod_d13894_idx'),
        ),
        migrations.AddIndex(
            model_name='country',
            index=models.Index(fields=['iso_code3'], name='countries_iso_cod_8f2712_idx'),
        ),
        migrations.AddIndex(
            model_name='country',
            index=models.Index(fields=['is_active'], name='countries_is_acti_f741bf_idx'),
        ),
        migrations.AddIndex(
            model_name='countryacceptedcurrency',
            index=models.Index(fields=['country'], name='country_acc_country_82dd69_idx'),
        ),
        migrations.AddIndex(
            model_name='countryacceptedcurrency',
            index=models.Index(fields=['currency'], name='country_acc_currenc_536bfc_idx'),
        ),
        migrations.AddIndex(
            model_name='countryacceptedcurrency',
            index=models.Index(fields=['is_active'], name='country_acc_is_acti_32992c_idx'),
        ),
        migrations.AddIndex(
            model_name='countryacceptedcurrency',
            index=models.Index(fields=['is_default'], name='country_acc_is_defa_fe326a_idx'),
        ),
        migrations.AddConstraint(
            model_name='countryacceptedcurrency',
            constraint=models.UniqueConstraint(
                condition=models.Q(('deleted_at__isnull', True)),
                fields=('country', 'currency'),
                name='unique_country_currency_active',
            ),
        ),
        migrations.RunPython(seed_usd_and_us, migrations.RunPython.noop),
        migrations.RenameField(
            model_name='organization',
            old_name='country',
            new_name='country_legacy',
        ),
        migrations.AddField(
            model_name='organization',
            name='country',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.PROTECT,
                related_name='organizations',
                to='organizations.country',
            ),
        ),
        migrations.AddField(
            model_name='organization',
            name='default_currency',
            field=models.ForeignKey(
                blank=True,
                help_text='Default CountryAcceptedCurrency for services/bookings when unspecified.',
                null=True,
                on_delete=django.db.models.deletion.PROTECT,
                related_name='organizations_defaulting',
                to='organizations.countryacceptedcurrency',
            ),
        ),
        migrations.RunPython(assign_org_country_and_default, migrations.RunPython.noop),
        migrations.CreateModel(
            name='OrganizationAddress',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('deleted_at', models.DateTimeField(blank=True, null=True)),
                ('address', models.CharField(max_length=255)),
                ('city', models.CharField(max_length=100)),
                ('postal_code', models.CharField(max_length=20)),
                (
                    'country_text',
                    models.CharField(
                        blank=True,
                        default='',
                        help_text='Legacy free-text country line; prefer country FK when set.',
                        max_length=100,
                    ),
                ),
                (
                    'country',
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.PROTECT,
                        related_name='organizationaddress_set',
                        to='organizations.country',
                    ),
                ),
                ('latitude', models.DecimalField(blank=True, decimal_places=6, max_digits=9, null=True)),
                ('longitude', models.DecimalField(blank=True, decimal_places=6, max_digits=9, null=True)),
                ('label', models.CharField(blank=True, max_length=128)),
                ('is_primary', models.BooleanField(default=False)),
                (
                    'organization',
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name='addresses',
                        to='organizations.organization',
                    ),
                ),
            ],
            options={
                'db_table': 'organization_addresses',
                'ordering': ['-is_primary', 'created_at'],
            },
        ),
        migrations.AddIndex(
            model_name='organizationaddress',
            index=models.Index(fields=['organization'], name='organizatio_organiz_a7a924_idx'),
        ),
        migrations.AddIndex(
            model_name='organizationaddress',
            index=models.Index(fields=['is_primary'], name='organizatio_is_prim_82979c_idx'),
        ),
        migrations.RunPython(copy_addresses, migrations.RunPython.noop),
        migrations.RemoveField(
            model_name='organization',
            name='address',
        ),
        migrations.RemoveField(
            model_name='organization',
            name='city',
        ),
        migrations.RemoveField(
            model_name='organization',
            name='postal_code',
        ),
        migrations.RemoveField(
            model_name='organization',
            name='country_legacy',
        ),
        migrations.RemoveField(
            model_name='organization',
            name='latitude',
        ),
        migrations.RemoveField(
            model_name='organization',
            name='longitude',
        ),
        migrations.AddIndex(
            model_name='organization',
            index=models.Index(fields=['country'], name='organizatio_country_ae4d6d_idx'),
        ),
    ]
