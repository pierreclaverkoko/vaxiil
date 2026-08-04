"""Payment catalog API + seed tests."""

from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from django.utils import translation
from rest_framework import status
from rest_framework.test import APIClient

from src.apps.payments.catalog import PaymentConnector, PaymentMethod
from src.apps.payments.catalog_seed import ensure_default_payment_catalog
from src.apps.payments.identifier_ui import (
    account_placeholder_for_method,
    identifier_type_for_method,
)
from src.apps.test_helpers.geo import seed_us_country_and_currency

User = get_user_model()


def _rows(data):
    return data['results'] if isinstance(data, dict) and 'results' in data else data


class PaymentCatalogApiTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.country, _ = seed_us_country_and_currency()
        ensure_default_payment_catalog()
        cls.user = User.objects.create_user(
            email='catalog@example.com',
            username='cataloguser',
            password='x',
        )
        cls.mma = PaymentConnector.objects.get(code='mm_aggregator')
        cls.operator = PaymentMethod.objects.create(
            connector=cls.mma,
            code='AIRTEL_COD_TEST',
            name='Airtel COD test',
            method_type=PaymentMethod.MethodType.MOBILE_MONEY,
            country=cls.country,
            account_regex=r'^\+?[0-9]{8,15}$',
            config={
                'provider_code': 'AIRTEL_COD',
                'destination_fields': ['phone_number', 'account_name'],
                'optional_fields': ['account_name'],
                'identifier_type': 'phone',
                'account_placeholder': {
                    'en': 'e.g. 97 000 0001',
                    'fr': 'ex. 97 000 0001',
                },
                'phone_country_codes': ['CD'],
            },
            supported_operations=[
                PaymentMethod.Operation.COLLECT,
                PaymentMethod.Operation.WALLET_FUND,
            ],
            is_active=True,
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

    def test_identifier_ui_fields_on_methods(self):
        api = APIClient()
        api.force_authenticate(user=self.user)
        res = api.get(
            '/api/v1/payments/methods/',
            {'operation': 'collect', 'q': 'AIRTEL_COD_TEST'},
            HTTP_ACCEPT_LANGUAGE='fr',
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        row = next(r for r in _rows(res.data) if r['code'] == 'AIRTEL_COD_TEST')
        self.assertEqual(row['identifier_type'], 'phone')
        self.assertEqual(row['account_placeholder'], 'ex. 97 000 0001')
        self.assertEqual(row['phone_country_codes'], ['CD'])
        self.assertEqual(row['account_regex'], r'^\+?[0-9]{8,15}$')

    def test_country_phone_code_exposed(self):
        api = APIClient()
        api.force_authenticate(user=self.user)
        res = api.get('/api/v1/organizations/countries/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        rows = _rows(res.data)
        us = next(r for r in rows if r.get('iso_code2') == 'US')
        self.assertEqual(us.get('phone_code'), '1')

    def test_placeholder_language_helper(self):
        with translation.override('fr'):
            self.assertEqual(
                account_placeholder_for_method(self.operator),
                'ex. 97 000 0001',
            )
        with translation.override('en'):
            self.assertEqual(
                account_placeholder_for_method(self.operator),
                'e.g. 97 000 0001',
            )
        self.assertEqual(identifier_type_for_method(self.operator), 'phone')


@override_settings(DJANGO_ADMIN_PATH='vx-mgmt/')
class AdminPathTests(TestCase):
    def test_obscure_admin_path_reachable(self):
        res = APIClient().get('/vx-mgmt/login/')
        self.assertIn(res.status_code, (200, 302))

    def test_legacy_admin_gone(self):
        res = APIClient().get('/admin/login/')
        self.assertEqual(res.status_code, 404)
