from django.test import TestCase

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
