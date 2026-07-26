# Generated manually: replace Service.city string with cities.City FK

import django.db.models.deletion
from django.contrib.gis.geos import Point
from django.db import migrations, models


def link_service_cities(apps, schema_editor):
    Service = apps.get_model('services', 'Service')
    CitiesCountry = apps.get_model('cities', 'Country')
    CitiesCity = apps.get_model('cities', 'City')
    Continent = apps.get_model('cities', 'Continent')

    continent, _ = Continent.objects.get_or_create(
        code='XX',
        defaults={'name': 'Placeholder', 'slug': 'placeholder'},
    )
    for svc in Service.objects.all():
        if svc.country_id:
            org_country = svc.country
            if getattr(org_country, 'cities_country_id', None):
                cc = CitiesCountry.objects.get(pk=org_country.cities_country_id)
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
        city_name = (svc.city or 'Unknown').strip()[:200] or 'Unknown'
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
        svc.cities_city_id = city.pk
        svc.save(update_fields=['cities_city_id'])


class Migration(migrations.Migration):

    dependencies = [
        ('cities', '0012_alter_country_neighbours'),
        ('organizations', '0014_cities_country_and_city_fk'),
        ('services', '0007_accepted_venues_reschedule_notifications'),
    ]

    operations = [
        migrations.AddField(
            model_name='service',
            name='cities_city',
            field=models.ForeignKey(
                null=True,
                on_delete=django.db.models.deletion.PROTECT,
                related_name='service_set',
                to='cities.city',
            ),
        ),
        migrations.RunPython(link_service_cities, migrations.RunPython.noop),
        migrations.RunSQL(
            'SET CONSTRAINTS ALL IMMEDIATE',
            reverse_sql=migrations.RunSQL.noop,
        ),
        migrations.AlterField(
            model_name='service',
            name='cities_city',
            field=models.ForeignKey(
                on_delete=django.db.models.deletion.PROTECT,
                related_name='service_set',
                to='cities.city',
            ),
        ),
        migrations.RemoveField(
            model_name='service',
            name='city',
        ),
    ]
