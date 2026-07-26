# Generated manually: link organizations.Country to cities.Country; replace address city string

import django.db.models.deletion
from django.contrib.gis.geos import Point
from django.db import migrations, models


def link_countries_to_cities(apps, schema_editor):
    Country = apps.get_model('organizations', 'Country')
    CitiesCountry = apps.get_model('cities', 'Country')
    Continent = apps.get_model('cities', 'Continent')

    continent, _ = Continent.objects.get_or_create(
        code='XX',
        defaults={'name': 'Placeholder', 'slug': 'placeholder'},
    )
    for row in Country.objects.all():
        code = (row.iso_code2 or 'XX').upper()[:2]
        cc, _ = CitiesCountry.objects.get_or_create(
            code=code,
            defaults={
                'name': row.name or code,
                'code3': (row.iso_code3 or (code + 'X'))[:3],
                'population': 1,
                'area': 1,
                'phone': '1',
                'tld': code.lower()[:5],
                'postal_code_format': '',
                'postal_code_regex': '',
                'capital': '',
                'continent_id': continent.pk,
                'slug': (row.name or code).lower().replace(' ', '-')[:255],
            },
        )
        row.cities_country_id = cc.pk
        row.save(update_fields=['cities_country_id'])


def link_address_cities(apps, schema_editor):
    OrganizationAddress = apps.get_model('organizations', 'OrganizationAddress')
    CitiesCountry = apps.get_model('cities', 'Country')
    CitiesCity = apps.get_model('cities', 'City')
    Continent = apps.get_model('cities', 'Continent')

    continent, _ = Continent.objects.get_or_create(
        code='XX',
        defaults={'name': 'Placeholder', 'slug': 'placeholder'},
    )
    for addr in OrganizationAddress.objects.all():
        code = 'US'
        if addr.country_id:
            org_country = addr.country
            if getattr(org_country, 'cities_country_id', None):
                cc = CitiesCountry.objects.get(pk=org_country.cities_country_id)
            else:
                code = (getattr(org_country, 'iso_code2', None) or 'US').upper()[:2]
                cc, _ = CitiesCountry.objects.get_or_create(
                    code=code,
                    defaults={
                        'name': code,
                        'code3': code + 'X',
                        'population': 1,
                        'area': 1,
                        'phone': '1',
                        'tld': code.lower(),
                        'postal_code_format': '',
                        'postal_code_regex': '',
                        'capital': '',
                        'continent_id': continent.pk,
                        'slug': code.lower(),
                    },
                )
        else:
            cc, _ = CitiesCountry.objects.get_or_create(
                code='US',
                defaults={
                    'name': 'United States',
                    'code3': 'USA',
                    'population': 1,
                    'area': 1,
                    'phone': '1',
                    'tld': 'us',
                    'postal_code_format': '',
                    'postal_code_regex': '',
                    'capital': '',
                    'continent_id': continent.pk,
                    'slug': 'united-states',
                },
            )
        city_name = (addr.city or 'Unknown').strip()[:200] or 'Unknown'
        city = CitiesCity.objects.filter(country_id=cc.pk, name=city_name).first()
        if city is None:
            city = CitiesCity.objects.create(
                country_id=cc.pk,
                name=city_name,
                name_std=city_name,
                location=Point(0, 0, srid=4326),
                population=1,
                kind='PPL',
                timezone='UTC',
                slug=city_name.lower().replace(' ', '-')[:255],
            )
        addr.cities_city_id = city.pk
        addr.save(update_fields=['cities_city_id'])


class Migration(migrations.Migration):

    dependencies = [
        ('cities', '0012_alter_country_neighbours'),
        ('organizations', '0013_accepted_venues_reschedule_notifications'),
    ]

    operations = [
        migrations.AddField(
            model_name='country',
            name='cities_country',
            field=models.OneToOneField(
                null=True,
                on_delete=django.db.models.deletion.PROTECT,
                related_name='vaxiil_country',
                to='cities.country',
            ),
        ),
        migrations.AddField(
            model_name='organizationaddress',
            name='cities_city',
            field=models.ForeignKey(
                null=True,
                on_delete=django.db.models.deletion.PROTECT,
                related_name='organizationaddress_set',
                to='cities.city',
            ),
        ),
        migrations.RunPython(link_countries_to_cities, migrations.RunPython.noop),
        migrations.RunPython(link_address_cities, migrations.RunPython.noop),
        # Flush deferred FK checks before ALTER (Postgres pending-trigger error).
        migrations.RunSQL(
            'SET CONSTRAINTS ALL IMMEDIATE',
            reverse_sql=migrations.RunSQL.noop,
        ),
        migrations.AlterField(
            model_name='country',
            name='cities_country',
            field=models.OneToOneField(
                on_delete=django.db.models.deletion.PROTECT,
                related_name='vaxiil_country',
                to='cities.country',
            ),
        ),
        migrations.AlterField(
            model_name='organizationaddress',
            name='cities_city',
            field=models.ForeignKey(
                on_delete=django.db.models.deletion.PROTECT,
                related_name='organizationaddress_set',
                to='cities.city',
            ),
        ),
        migrations.RemoveIndex(
            model_name='country',
            name='countries_iso_cod_d13894_idx',
        ),
        migrations.RemoveIndex(
            model_name='country',
            name='countries_iso_cod_8f2712_idx',
        ),
        migrations.RemoveField(
            model_name='country',
            name='iso_code2',
        ),
        migrations.RemoveField(
            model_name='country',
            name='iso_code3',
        ),
        migrations.RemoveField(
            model_name='country',
            name='name',
        ),
        migrations.RemoveField(
            model_name='organizationaddress',
            name='city',
        ),
        migrations.AlterModelOptions(
            name='country',
            options={'ordering': ['cities_country__name']},
        ),
    ]
