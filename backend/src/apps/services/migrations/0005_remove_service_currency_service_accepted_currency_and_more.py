# Fixed: rename legacy country char, then add FK and accepted_currency

import django.db.models.deletion
from django.db import migrations, models


def fill_service_currency(apps, schema_editor):
    Service = apps.get_model('services', 'Service')
    for svc in Service.objects.all():
        org = svc.organization
        if org.default_currency_id:
            svc.accepted_currency_id = org.default_currency_id
            svc.save(update_fields=['accepted_currency_id'])
        if org.country_id and not svc.country_id:
            svc.country_id = org.country_id
            svc.save(update_fields=['country_id'])


class Migration(migrations.Migration):
    atomic = False

    dependencies = [
        ('organizations', '0006_country_currency_link_and_addresses'),
        ('services', '0004_service_category_icon_help_text'),
    ]

    operations = [
        migrations.RemoveField(
            model_name='service',
            name='currency',
        ),
        migrations.RenameField(
            model_name='service',
            old_name='country',
            new_name='country_text',
        ),
        migrations.AddField(
            model_name='service',
            name='country',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.PROTECT,
                related_name='service_set',
                to='organizations.country',
            ),
        ),
        migrations.AddField(
            model_name='service',
            name='accepted_currency',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.PROTECT,
                related_name='services',
                to='organizations.countryacceptedcurrency',
            ),
        ),
        migrations.AddField(
            model_name='service',
            name='show_location_on_listing',
            field=models.BooleanField(
                default=True,
                help_text='When false, service address is hidden from public catalog.',
            ),
        ),
        migrations.RunPython(fill_service_currency, migrations.RunPython.noop),
    ]
