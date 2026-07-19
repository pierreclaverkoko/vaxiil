"""GET /organizations/discovery/ lists verified orgs (public, AllowAny)."""

from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from src.apps.organizations.models import Organization, OrganizationTypeModel
from src.apps.test_helpers.geo import create_org_address, seed_us_country_and_currency

User = get_user_model()


class OrganizationDiscoveryAPITests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.country, cls.cac = seed_us_country_and_currency()
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

    def test_discovery_returns_verified_only(self):
        res = self.client.get('/api/v1/organizations/discovery/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertIsInstance(res.data, list)
        ids = {str(x['id']) for x in res.data}
        self.assertIn(str(self.verified.id), ids)
        self.assertNotIn(str(self.pending.id), ids)

    def test_discovery_includes_city_and_truncated_description(self):
        res = self.client.get('/api/v1/organizations/discovery/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        row = next(x for x in res.data if x['id'] == str(self.verified.id))
        self.assertEqual(row['city'], 'Brooklyn')
        self.assertIn('Holistic', row['description'])

    def test_discovery_allows_anonymous(self):
        self.client.force_authenticate(user=None)
        res = self.client.get('/api/v1/organizations/discovery/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        ids = {str(x['id']) for x in res.data}
        self.assertIn(str(self.verified.id), ids)
        self.assertNotIn(str(self.pending.id), ids)
