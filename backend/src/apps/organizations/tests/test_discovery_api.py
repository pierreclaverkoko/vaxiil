"""GET /organizations/discovery/ lists verified orgs (public, AllowAny)."""

from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from src.apps.organizations.models import Country, Organization, OrganizationTypeModel
from src.apps.test_helpers.geo import create_org_address, seed_cities_country, seed_us_country_and_currency

User = get_user_model()


class OrganizationDiscoveryAPITests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.country, cls.cac = seed_us_country_and_currency()
        cities_cm, _ = seed_cities_country(
            code='CM',
            code3='CMR',
            name='Cameroon',
            city_name='Douala',
            lng=9.7,
            lat=4.05,
        )
        cls.cm, _ = Country.objects.get_or_create(
            cities_country=cities_cm,
            defaults={'flag': '', 'is_active': True},
        )
        cls.org_type = OrganizationTypeModel.objects.create(
            name='spa', display_name='Spa'
        )
        cls.verified = Organization.objects.create(
            name='The Sage Sanctuary',
            type=cls.org_type,
            email='sage@example.com',
            country=cls.country,
            default_currency=cls.cac,
            verification_status=Organization.VerificationStatus.VERIFIED,
            description='Holistic Therapy & Aromatherapy for everyone.',
        )
        create_org_address(cls.verified, cls.country, city='Brooklyn')
        cls.verified_cm = Organization.objects.create(
            name='Douala Wellness',
            type=cls.org_type,
            email='douala@example.com',
            country=cls.cm,
            default_currency=cls.cac,
            verification_status=Organization.VerificationStatus.VERIFIED,
            description='Spa in Douala.',
        )
        create_org_address(cls.verified_cm, cls.cm, city='Douala')
        cls.pending = Organization.objects.create(
            name='Hidden Pending',
            type=cls.org_type,
            email='pending@example.com',
            country=cls.country,
            default_currency=cls.cac,
            verification_status=Organization.VerificationStatus.PENDING,
        )
        create_org_address(cls.pending, cls.country, city='Queens')

        cls.stranger = User.objects.create_user(
            email='stranger@example.com',
            username='stranger',
            password='secret123',
            role=User.UserRole.CLIENT,
        )

    def setUp(self):
        self.client = APIClient()
        self.client.force_authenticate(user=self.stranger)

    def _results(self, res):
        data = res.data
        if isinstance(data, dict) and 'results' in data:
            return data['results']
        return data

    def test_discovery_returns_verified_only(self):
        res = self.client.get('/api/v1/organizations/discovery/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        rows = self._results(res)
        self.assertIsInstance(rows, list)
        ids = {str(x['id']) for x in rows}
        self.assertIn(str(self.verified.id), ids)
        self.assertNotIn(str(self.pending.id), ids)

    def test_discovery_includes_city_and_truncated_description(self):
        res = self.client.get('/api/v1/organizations/discovery/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        row = next(x for x in self._results(res) if x['id'] == str(self.verified.id))
        self.assertEqual(row['city']['name'], 'Brooklyn')
        self.assertIn('Holistic', row['description'])

    def test_discovery_allows_anonymous(self):
        self.client.force_authenticate(user=None)
        res = self.client.get('/api/v1/organizations/discovery/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        ids = {str(x['id']) for x in self._results(res)}
        self.assertIn(str(self.verified.id), ids)
        self.assertNotIn(str(self.pending.id), ids)

    def test_discovery_filters_by_country_query(self):
        res = self.client.get(
            '/api/v1/organizations/discovery/',
            {'country': str(self.cm.id)},
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        ids = {str(x['id']) for x in self._results(res)}
        self.assertEqual(ids, {str(self.verified_cm.id)})

    def test_discovery_filters_by_x_country_header(self):
        res = self.client.get(
            '/api/v1/organizations/discovery/',
            HTTP_X_COUNTRY='CM',
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        ids = {str(x['id']) for x in self._results(res)}
        self.assertEqual(ids, {str(self.verified_cm.id)})

    def test_discovery_is_paginated(self):
        res = self.client.get(
            '/api/v1/organizations/discovery/',
            {'page_size': 1},
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertIn('results', res.data)
        self.assertEqual(res.data['count'], 2)
        self.assertEqual(len(res.data['results']), 1)
