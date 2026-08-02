"""Payment catalog API + seed tests."""

from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from rest_framework import status
from rest_framework.test import APIClient

from src.apps.payments.catalog import PaymentMethod
from src.apps.payments.catalog_seed import ensure_default_payment_catalog
from src.apps.test_helpers.geo import seed_us_country_and_currency

User = get_user_model()


def _rows(data):
    return data['results'] if isinstance(data, dict) and 'results' in data else data


class PaymentCatalogApiTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        seed_us_country_and_currency()
        ensure_default_payment_catalog()
        cls.user = User.objects.create_user(
            email='catalog@example.com',
            username='cataloguser',
            password='x',
        )

    def test_methods_require_auth(self):
        res = APIClient().get('/api/v1/payments/methods/')
        self.assertEqual(res.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_list_settlement_methods(self):
        api = APIClient()
        api.force_authenticate(user=self.user)
        res = api.get('/api/v1/payments/methods/', {'operation': 'settlement'})
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        codes = {row['code'] for row in _rows(res.data)}
        self.assertIn('SWIFT_IBAN', codes)
        self.assertIn('INTERAC_CA', codes)

    def test_q_search(self):
        api = APIClient()
        api.force_authenticate(user=self.user)
        res = api.get('/api/v1/payments/methods/', {'q': 'interac'})
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(any(r['code'] == 'INTERAC_CA' for r in _rows(res.data)))

    def test_list_collect_methods(self):
        api = APIClient()
        api.force_authenticate(user=self.user)
        res = api.get('/api/v1/payments/methods/', {'operation': 'collect'})
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        rows = _rows(res.data)
        self.assertTrue(any(r['code'].startswith('MOMO_') for r in rows))
        momo = next(r for r in rows if r['code'].startswith('MOMO_'))
        self.assertEqual(momo['connector']['code'], 'mm_aggregator')

    def test_connectors_list(self):
        api = APIClient()
        api.force_authenticate(user=self.user)
        res = api.get('/api/v1/payments/connectors/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        codes = {row['code'] for row in _rows(res.data)}
        self.assertTrue({'manual', 'mm_aggregator', 'blaaiz'}.issubset(codes))


@override_settings(DJANGO_ADMIN_PATH='vx-mgmt/')
class AdminPathTests(TestCase):
    def test_obscure_admin_path_reachable(self):
        res = APIClient().get('/vx-mgmt/login/')
        self.assertIn(res.status_code, (200, 302))

    def test_legacy_admin_gone(self):
        res = APIClient().get('/admin/login/')
        self.assertEqual(res.status_code, 404)
