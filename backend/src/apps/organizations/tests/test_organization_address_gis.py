"""GeoDjango PointField on OrganizationAddress stays in sync with lat/lon."""

from decimal import Decimal

from django.test import TestCase

from src.apps.organizations.models import (
    Organization,
    OrganizationTypeModel,
)
from src.apps.test_helpers.geo import create_org_address, seed_us_country_and_currency


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
        addr = create_org_address(
            self.org,
            self.country,
            city='Portland',
            address='1 St',
            latitude=Decimal('45.5152'),
            longitude=Decimal('-122.6784'),
        )
        addr.refresh_from_db()
        self.assertIsNotNone(addr.location)
        self.assertAlmostEqual(addr.location.y, 45.5152, places=4)
        self.assertAlmostEqual(addr.location.x, -122.6784, places=4)

    def test_clearing_coordinates_clears_location(self):
        addr = create_org_address(
            self.org,
            self.country,
            city='Portland',
            address='1 St',
            latitude=Decimal('45.5152'),
            longitude=Decimal('-122.6784'),
        )
        addr.latitude = None
        addr.longitude = None
        addr.save()
        addr.refresh_from_db()
        self.assertIsNone(addr.location)
