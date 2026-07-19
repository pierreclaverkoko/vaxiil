# Generated manually for GeoDjango PointField on primary addresses.

from django.contrib.gis.db.models import PointField
from django.contrib.gis.geos import Point
from django.db import migrations


def backfill_location_from_lat_lon(apps, schema_editor):
    OrganizationAddress = apps.get_model('organizations', 'OrganizationAddress')
    qs = OrganizationAddress.objects.exclude(latitude__isnull=True).exclude(
        longitude__isnull=True,
    )
    for row in qs.iterator():
        pt = Point(float(row.longitude), float(row.latitude), srid=4326)
        OrganizationAddress.objects.filter(pk=row.pk).update(location=pt)


def clear_locations(apps, schema_editor):
    OrganizationAddress = apps.get_model('organizations', 'OrganizationAddress')
    OrganizationAddress.objects.all().update(location=None)


class Migration(migrations.Migration):

    dependencies = [
        ('organizations', '0008_organization_logo'),
    ]

    operations = [
        migrations.AddField(
            model_name='organizationaddress',
            name='location',
            field=PointField(
                blank=True,
                geography=True,
                null=True,
                srid=4326,
            ),
        ),
        migrations.RunPython(backfill_location_from_lat_lon, clear_locations),
    ]
