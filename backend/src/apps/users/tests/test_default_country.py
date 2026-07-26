"""User profile default_country read/write."""

from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from src.apps.test_helpers.geo import seed_us_country_and_currency

User = get_user_model()


class UserDefaultCountryApiTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.country, _cac = seed_us_country_and_currency()
        cls.user = User.objects.create_user(
            email='geo@example.com',
            username='geouser',
            password='secret123',
        )

    def setUp(self):
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)

    def test_patch_default_country(self):
        res = self.client.put(
            '/api/v1/auth/profile/',
            {
                'first_name': '',
                'last_name': '',
                'default_country_id': str(self.country.id),
            },
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['default_country']['id'], str(self.country.id))
        self.user.refresh_from_db()
        self.assertEqual(self.user.default_country_id, self.country.id)

    def test_clear_default_country(self):
        self.user.default_country = self.country
        self.user.save(update_fields=['default_country'])
        res = self.client.put(
            '/api/v1/auth/profile/',
            {
                'first_name': '',
                'last_name': '',
                'default_country_id': None,
            },
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.user.refresh_from_db()
        self.assertIsNone(self.user.default_country_id)
