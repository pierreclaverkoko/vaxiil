"""GeoDjango PointField on OrganizationAddress stays in sync with lat/lon."""

from decimal import Decimal

from django.test import TestCase

from src.apps.organizations.models import (
    Organization,
    OrganizationAddress,
    OrganizationTypeModel,
)
from src.apps.test_helpers.geo import seed_us_country_and_currency


class OrganizationAddressLocationTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.country, cls.cac = seed_us_country_and_currency()
        cls.org_type = OrganizationTypeModel.objects.create(
            name='spa',
            display_name='Spa',
        )
        cls.org = Organization.objects.create(
            name='Geo Org',
            type=cls.org_type,
            email='geo@example.com',
            country=cls.country,
            default_currency=cls.cac,
        )

    def test_save_sets_location_from_latitude_longitude(self):
        addr = OrganizationAddress.objects.create(
            organization=self.org,
            address='1 St',
            city='Portland',
            postal_code='97209',
            country=self.country,
            is_primary=True,
            latitude=Decimal('45.5152'),
            longitude=Decimal('-122.6784'),
        )
        addr.refresh_from_db()
        self.assertIsNotNone(addr.location)
        self.assertAlmostEqual(addr.location.y, 45.5152, places=4)
        self.assertAlmostEqual(addr.location.x, -122.6784, places=4)

    def test_clearing_coordinates_clears_location(self):
        addr = OrganizationAddress.objects.create(
            organization=self.org,
            address='1 St',
            city='Portland',
            postal_code='97209',
            country=self.country,
            is_primary=True,
            latitude=Decimal('45.5152'),
            longitude=Decimal('-122.6784'),
        )
        addr.latitude = None
        addr.longitude = None
        addr.save()
        addr.refresh_from_db()
        self.assertIsNone(addr.location)
