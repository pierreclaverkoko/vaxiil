"""PATCH /organizations/:id/ with primary address fields."""

from decimal import Decimal

from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from src.apps.organizations.models import (
    Organization,
    OrganizationMembership,
    OrganizationTypeModel,
)
from src.apps.test_helpers.geo import create_org_address, seed_us_country_and_currency

User = get_user_model()


class OrganizationUpdatePrimaryAddressAPITests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.country, cls.cac = seed_us_country_and_currency()
        cls.org_type = OrganizationTypeModel.objects.create(
            name='spa',
            display_name='Spa',
        )
        cls.owner = User.objects.create_user(
            email='owner@example.com',
            username='owner',
            password='secret123',
            role=User.UserRole.CLIENT,
        )
        cls.org = Organization.objects.create(
            name='Verdant Pulse',
            type=cls.org_type,
            email='verdant@example.com',
            country=cls.country,
            default_currency=cls.cac,
        )
        create_org_address(
            cls.org,
            cls.country,
            address='820 NW 12th Ave',
            city='Portland',
            postal_code='97209',
        )
        OrganizationMembership.objects.create(
            user=cls.owner,
            organization=cls.org,
            role=OrganizationMembership.OrganizationMemberRole.OWNER,
        )

        cls.org_no_addr = Organization.objects.create(
            name='No Address Org',
            type=cls.org_type,
            email='noaddr@example.com',
            country=cls.country,
            default_currency=cls.cac,
        )
        OrganizationMembership.objects.create(
            user=cls.owner,
            organization=cls.org_no_addr,
            role=OrganizationMembership.OrganizationMemberRole.OWNER,
        )

    def setUp(self):
        self.client = APIClient()
        self.client.force_authenticate(user=self.owner)

    def test_patch_updates_primary_address_fields(self):
        res = self.client.patch(
            f'/api/v1/organizations/{self.org.id}/',
            {
                'primary_address': '99 Main St',
                'primary_city': 'Seattle',
                'primary_postal_code': '98101',
                'primary_latitude': '47.6062',
                'primary_longitude': '-122.3321',
            },
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        pa = self.org.primary_address()
        self.assertIsNotNone(pa)
        pa.refresh_from_db()
        self.assertEqual(pa.address, '99 Main St')
        self.assertEqual(pa.city, 'Seattle')
        self.assertEqual(pa.postal_code, '98101')
        self.assertEqual(pa.latitude, Decimal('47.606200'))
        self.assertEqual(pa.longitude, Decimal('-122.332100'))

    def test_patch_creates_primary_when_missing(self):
        res = self.client.patch(
            f'/api/v1/organizations/{self.org_no_addr.id}/',
            {
                'primary_address': '1 First St',
                'primary_city': 'Austin',
                'primary_postal_code': '78701',
                'primary_country_text': '',
            },
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.org_no_addr.refresh_from_db()
        pa = self.org_no_addr.primary_address()
        self.assertIsNotNone(pa)
        self.assertEqual(pa.address, '1 First St')
        self.assertEqual(pa.city, 'Austin')
        self.assertEqual(pa.postal_code, '78701')
        self.assertTrue(pa.is_primary)

    def test_patch_primary_country_requires_full_address_when_none_exists(self):
        res = self.client.patch(
            f'/api/v1/organizations/{self.org_no_addr.id}/',
            {'primary_latitude': '30.0'},
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('primary_address', res.data)

    def test_patch_top_level_country_syncs_primary_address_country(self):
        from src.apps.finances.models import Currency
        from src.apps.organizations.models import Country, CountryAcceptedCurrency

        cur_usd = Currency.objects.get(code='USD')
        mx = Country.objects.create(
            iso_code2='MX',
            iso_code3='MEX',
            name='Mexico',
            flag='',
            is_active=True,
        )
        cac_mx = CountryAcceptedCurrency.objects.create(
            country=mx,
            currency=cur_usd,
            is_active=True,
            is_default=True,
        )

        res = self.client.patch(
            f'/api/v1/organizations/{self.org.id}/',
            {
                'country': str(mx.id),
                'default_currency': str(cac_mx.id),
            },
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        pa = self.org.primary_address()
        pa.refresh_from_db()
        self.assertEqual(pa.country_id, mx.id)
