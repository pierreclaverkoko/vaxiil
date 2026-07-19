from decimal import Decimal

from django.db import migrations


def seed_settings(apps, schema_editor):
    PlatformSettings = apps.get_model('finances', 'PlatformSettings')
    PlatformSettings.objects.get_or_create(
        pk=1,
        defaults={'platform_fee_rate': Decimal('1.00')},
    )


def unseed(apps, schema_editor):
    PlatformSettings = apps.get_model('finances', 'PlatformSettings')
    PlatformSettings.objects.filter(pk=1).delete()


class Migration(migrations.Migration):
    dependencies = [
        ('finances', '0002_platform_fees'),
    ]

    operations = [
        migrations.RunPython(seed_settings, unseed),
    ]
