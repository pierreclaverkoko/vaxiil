"""Nested organization address CRUD + city autocomplete."""

from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from src.apps.organizations.models import (
    Organization,
    OrganizationAddress,
    OrganizationMembership,
    OrganizationTypeModel,
)
from src.apps.test_helpers.geo import (
    create_org_address,
    seed_cities_country,
    seed_us_country_and_currency,
)

User = get_user_model()


class OrganizationAddressesApiTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.country, cls.cac = seed_us_country_and_currency()
        _cc, cls.nyc = seed_cities_country(city_name='New York')
        _cc, cls.seattle = seed_cities_country(city_name='Seattle', lat=47.6, lng=-122.3)
        cls.org_type = OrganizationTypeModel.objects.create(
            name='spa',
            display_name='Spa',
        )
        cls.owner = User.objects.create_user(
            email='owner@example.com',
            username='owner',
            password='secret123',
        )
        cls.org = Organization.objects.create(
            name='Address Org',
            type=cls.org_type,
            email='addr@example.com',
            country=cls.country,
            default_currency=cls.cac,
        )
        create_org_address(
            cls.org,
            cls.country,
            address='1 Main',
            cities_city=cls.nyc,
            postal_code='10001',
        )
        OrganizationMembership.objects.create(
            user=cls.owner,
            organization=cls.org,
            role=OrganizationMembership.OrganizationMemberRole.OWNER,
        )

    def setUp(self):
        self.client = APIClient()
        self.client.force_authenticate(user=self.owner)

    def test_list_addresses(self):
        res = self.client.get(f'/api/v1/organizations/{self.org.id}/addresses/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        rows = res.data if isinstance(res.data, list) else res.data.get('results', res.data)
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]['city']['name'], 'New York')
        self.assertTrue(rows[0]['is_primary'])

    def test_create_secondary_address(self):
        res = self.client.post(
            f'/api/v1/organizations/{self.org.id}/addresses/',
            {
                'label': 'West',
                'address': '99 Pine',
                'city_id': self.seattle.pk,
                'postal_code': '98101',
                'is_primary': False,
                'latitude': '47.6062',
                'longitude': '-122.3321',
            },
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res.data['city']['name'], 'Seattle')
        self.assertFalse(res.data['is_primary'])
        self.assertEqual(
            OrganizationAddress.objects.filter(organization=self.org).count(),
            2,
        )

    def test_set_primary_clears_previous(self):
        secondary = OrganizationAddress.objects.create(
            organization=self.org,
            address='2 Second',
            cities_city=self.seattle,
            postal_code='98101',
            country=self.country,
            is_primary=False,
        )
        res = self.client.patch(
            f'/api/v1/organizations/{self.org.id}/addresses/{secondary.id}/',
            {'is_primary': True},
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(res.data['is_primary'])
        primary = self.org.primary_address()
        self.assertEqual(primary.id, secondary.id)

    def test_cities_autocomplete(self):
        res = self.client.get(
            '/api/v1/organizations/cities/',
            {'country': str(self.country.id), 'q': 'Sea'},
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        rows = res.data if isinstance(res.data, list) else res.data.get('results', res.data)
        names = {r['name'] for r in rows}
        self.assertIn('Seattle', names)
