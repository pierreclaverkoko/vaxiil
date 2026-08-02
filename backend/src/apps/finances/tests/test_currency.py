from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from src.apps.finances.models import Currency


class CurrencyModelTests(TestCase):
    def test_create(self):
        c = Currency.objects.create(
            code='EUR',
            symbol='€',
            name='Euro',
            numeric_code='978',
            minor_units=2,
        )
        self.assertEqual(c.code, 'EUR')
        self.assertEqual(str(c), 'EUR (Euro)')


class CurrencySearchApiTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        Currency.objects.get_or_create(
            code='USD',
            defaults=dict(symbol='$', name='US Dollar', numeric_code='840'),
        )
        Currency.objects.get_or_create(
            code='CAD',
            defaults=dict(symbol='C$', name='Canadian Dollar', numeric_code='124'),
        )
        Currency.objects.get_or_create(
            code='EUR',
            defaults=dict(symbol='€', name='Euro', numeric_code='978'),
        )

    def test_list_all_active(self):
        res = APIClient().get('/api/v1/finances/currencies/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        rows = res.data['results'] if isinstance(res.data, dict) else res.data
        codes = {row['code'] for row in rows}
        self.assertTrue({'USD', 'CAD', 'EUR'}.issubset(codes))

    def test_q_filters_code_and_name(self):
        res = APIClient().get('/api/v1/finances/currencies/', {'q': 'can'})
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        rows = res.data['results'] if isinstance(res.data, dict) else res.data
        codes = [row['code'] for row in rows]
        self.assertEqual(codes, ['CAD'])

        res2 = APIClient().get('/api/v1/finances/currencies/', {'q': 'us'})
        rows2 = res2.data['results'] if isinstance(res2.data, dict) else res2.data
        codes2 = {row['code'] for row in rows2}
        self.assertIn('USD', codes2)
