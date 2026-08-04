"""Consumer payment transaction list API tests."""

from __future__ import annotations

from decimal import Decimal

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APIClient

from src.apps.bookings.models import Booking
from src.apps.organizations.models import Organization, OrganizationTypeModel
from src.apps.payments.catalog import PaymentConnector, PaymentMethod
from src.apps.payments.models import PaymentProvider, PaymentTransaction
from src.apps.services.models import Service, ServiceCategory, ServiceSubCategory
from src.apps.test_helpers.geo import seed_cities_country, seed_us_country_and_currency

User = get_user_model()


def _seed():
    ctry, cac = seed_us_country_and_currency()
    return ctry, cac, cac.currency


class ConsumerTransactionListApiTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.country, cls.cac, cls.currency = _seed()
        cls.org_type = OrganizationTypeModel.objects.create(
            name='spa',
            display_name='Spa',
        )
        cls.customer = User.objects.create_user(
            email='payer@example.com',
            username='payer',
            password='pass12345',
        )
        cls.customer.inscription_fee_paid_at = timezone.now()
        cls.customer.save(update_fields=['inscription_fee_paid_at'])
        cls.other = User.objects.create_user(
            email='other@example.com',
            username='other',
            password='pass12345',
        )
        cls.org = Organization.objects.create(
            name='Pay Org',
            type=cls.org_type,
            email='pay@example.com',
            country=cls.country,
            default_currency=cls.cac,
        )
        cat = ServiceCategory.objects.create(name='Massage')
        sub = ServiceSubCategory.objects.create(name='Swedish', category=cat)
        cls.service = Service.objects.create(
            cities_city=seed_cities_country(city_name='NYC')[1],
            name='Swedish',
            sub_category=sub,
            organization=cls.org,
            description='x',
            price_min=50,
            price_max=100,
            accepted_currency=cls.cac,
            address='1 Main',
            postal_code='10001',
            country_text='US',
            country=cls.country,
        )
        cls.provider = PaymentProvider.objects.create(
            code='mm_aggregator',
            provider_type=PaymentProvider.ProviderType.OTHER,
            display_name='Secure payment',
            is_active=True,
            config={},
        )
        mma, _ = PaymentConnector.objects.get_or_create(
            code='mm_aggregator',
            defaults={
                'name': 'MM Aggregator',
                'connector_type': PaymentConnector.ConnectorType.AGGREGATOR,
                'adapter_key': 'mm_aggregator',
                'is_active': True,
            },
        )
        cls.method = PaymentMethod.objects.create(
            code='MOMO_TEST',
            connector=mma,
            name='Test MoMo',
            method_type=PaymentMethod.MethodType.MOBILE_MONEY,
            account_regex=r'^\+?[0-9]{8,15}$',
            config={'provider_code': 'MPESA_KE'},
            supported_operations=[
                PaymentMethod.Operation.COLLECT,
                PaymentMethod.Operation.WALLET_FUND,
            ],
            is_active=True,
        )
        cls.booking = Booking.objects.create(
            user=cls.customer,
            service=cls.service,
            organization=cls.org,
            status=Booking.BookingStatus.REQUESTED,
            base_price=Decimal('50.00'),
            total_price=Decimal('50.00'),
            accepted_currency=cls.cac,
        )

    def setUp(self):
        self.api = APIClient()
        self.api.force_authenticate(user=self.customer)

    def _create_txn(self, *, user=None, **kwargs):
        defaults = {
            'booking': self.booking,
            'payment_provider': self.provider,
            'user': user or self.customer,
            'amount': Decimal('50.00'),
            'currency': self.currency,
            'kind': PaymentTransaction.TransactionKind.PAYMENT,
            'status': PaymentTransaction.TransactionStatus.SUCCEEDED,
            'purpose': PaymentTransaction.Purpose.BOOKING,
            'client_reference': f'ref_{PaymentTransaction.objects.count()}',
        }
        defaults.update(kwargs)
        return PaymentTransaction.objects.create(**defaults)

    def test_unauthenticated_rejected(self):
        anon = APIClient()
        res = anon.get('/api/v1/payments/transactions/')
        self.assertEqual(res.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_empty_list(self):
        res = self.api.get('/api/v1/payments/transactions/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['count'], 0)
        self.assertEqual(res.data['results'], [])

    def test_lists_own_transactions_only(self):
        own = self._create_txn(client_reference='own_ref')
        self._create_txn(
            user=self.other,
            booking=None,
            purpose=PaymentTransaction.Purpose.WALLET_TOP_UP,
            client_reference='other_ref',
        )
        res = self.api.get('/api/v1/payments/transactions/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['count'], 1)
        row = res.data['results'][0]
        self.assertEqual(row['id'], str(own.id))
        self.assertEqual(row['client_reference'], 'own_ref')
        self.assertEqual(row['booking'], str(self.booking.id))
        self.assertEqual(row['currency_code'], 'USD')
        self.assertEqual(row['provider_code'], 'mm_aggregator')
        self.assertEqual(row['amount'], '50.00')

    def test_choice_enum_shape_and_css(self):
        self._create_txn(
            purpose=PaymentTransaction.Purpose.WALLET_TOP_UP,
            booking=None,
            status=PaymentTransaction.TransactionStatus.PENDING,
            kind=PaymentTransaction.TransactionKind.PAYMENT,
            client_reference='wallet_ref',
        )
        res = self.api.get('/api/v1/payments/transactions/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        row = res.data['results'][0]
        self.assertEqual(row['status']['value'], 'N')
        self.assertEqual(row['status']['css'], 'warning')
        self.assertIn('title', row['status'])
        self.assertEqual(row['kind']['value'], 'P')
        self.assertEqual(row['kind']['css'], 'primary')
        self.assertEqual(row['purpose']['value'], 'W')
        self.assertEqual(row['purpose']['css'], 'success')

    def test_filter_by_status_and_purpose(self):
        self._create_txn(
            status=PaymentTransaction.TransactionStatus.SUCCEEDED,
            purpose=PaymentTransaction.Purpose.BOOKING,
            client_reference='ok_booking',
        )
        self._create_txn(
            status=PaymentTransaction.TransactionStatus.FAILED,
            purpose=PaymentTransaction.Purpose.BOOKING,
            booking=None,
            client_reference='fail_booking',
        )
        self._create_txn(
            status=PaymentTransaction.TransactionStatus.SUCCEEDED,
            purpose=PaymentTransaction.Purpose.WALLET_TOP_UP,
            booking=None,
            client_reference='ok_wallet',
        )
        by_status = self.api.get('/api/v1/payments/transactions/', {'status': 'F'})
        self.assertEqual(by_status.status_code, status.HTTP_200_OK)
        self.assertEqual(by_status.data['count'], 1)
        self.assertEqual(by_status.data['results'][0]['client_reference'], 'fail_booking')

        by_purpose = self.api.get('/api/v1/payments/transactions/', {'purpose': 'W'})
        self.assertEqual(by_purpose.status_code, status.HTTP_200_OK)
        self.assertEqual(by_purpose.data['count'], 1)
        self.assertEqual(by_purpose.data['results'][0]['client_reference'], 'ok_wallet')

    def test_status_poll_still_works(self):
        self._create_txn(client_reference='poll_me')
        res = self.api.get('/api/v1/payments/transactions/poll_me/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['client_reference'], 'poll_me')
        self.assertEqual(res.data['status_code'], 'S')
        self.assertEqual(res.data['status']['value'], 'S')
        self.assertEqual(res.data['transaction_id'], str(
            PaymentTransaction.objects.get(client_reference='poll_me').id
        ))
        self.assertIn('updated_at', res.data)
        self.assertTrue(res.data['can_refresh_status'])

    def test_wallet_refund_cannot_refresh_status(self):
        self._create_txn(
            client_reference='wallet_refund_ref',
            kind=PaymentTransaction.TransactionKind.REFUND,
            status=PaymentTransaction.TransactionStatus.REFUNDED,
            provider_response_code='wallet_credit',
            provider_response_body={'destination': 'wallet'},
        )
        res = self.api.get('/api/v1/payments/transactions/wallet_refund_ref/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertFalse(res.data['can_refresh_status'])
        list_res = self.api.get('/api/v1/payments/transactions/')
        self.assertEqual(list_res.status_code, status.HTTP_200_OK)
        row = next(
            r
            for r in list_res.data['results']
            if r['client_reference'] == 'wallet_refund_ref'
        )
        self.assertFalse(row['can_refresh_status'])

    def test_includes_payment_method_and_identifier(self):
        self.method.country = self.country
        self.method.save(update_fields=['country'])
        self._create_txn(
            client_reference='momo_ref',
            payer_account_masked='+25•••5678',
            provider_request_payload={
                'payment_method_id': str(self.method.id),
                'customer_phone': '+254712345678',
            },
        )
        res = self.api.get('/api/v1/payments/transactions/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        row = res.data['results'][0]
        self.assertEqual(row['account_identifier'], '+25•••5678')
        method = row['payment_method']
        self.assertIsNotNone(method)
        self.assertEqual(method['id'], str(self.method.id))
        self.assertEqual(method['name'], 'Test MoMo')
        self.assertEqual(method['code'], 'MOMO_TEST')
        self.assertEqual(method['method_type']['value'], 'M')
        self.assertEqual(method['method_type']['css'], 'info')
        self.assertIn('logo_url', method)
        self.assertIsNotNone(method['country'])
        self.assertEqual(method['country']['iso_code2'], self.country.iso_code2)
        self.assertIn('flag', method['country'])
        self.assertIn('name', method['country'])

    def test_detail_includes_country_flag(self):
        self.method.country = self.country
        self.method.save(update_fields=['country'])
        self._create_txn(
            client_reference='detail_ref',
            provider_request_payload={
                'payment_method_id': str(self.method.id),
            },
        )
        res = self.api.get('/api/v1/payments/transactions/detail_ref/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        country = res.data['payment_method']['country']
        self.assertEqual(country['id'], str(self.country.id))
        self.assertEqual(country['iso_code2'], self.country.iso_code2)
        self.assertIn('flag', country)

    def test_detail_other_user_404(self):
        self._create_txn(
            user=self.other,
            booking=None,
            purpose=PaymentTransaction.Purpose.WALLET_TOP_UP,
            client_reference='secret_ref',
        )
        res = self.api.get('/api/v1/payments/transactions/secret_ref/')
        self.assertEqual(res.status_code, status.HTTP_404_NOT_FOUND)

    def test_refresh_other_user_404(self):
        self._create_txn(
            user=self.other,
            booking=None,
            purpose=PaymentTransaction.Purpose.WALLET_TOP_UP,
            client_reference='secret_refresh',
        )
        res = self.api.post('/api/v1/payments/transactions/secret_refresh/refresh/')
        self.assertEqual(res.status_code, status.HTTP_404_NOT_FOUND)

    def test_refresh_pending_to_succeeded(self):
        txn = self._create_txn(
            client_reference='refresh_me',
            status=PaymentTransaction.TransactionStatus.PENDING,
        )
        from unittest.mock import patch

        from src.apps.payments.adapters.base import CollectResult

        fake = CollectResult(
            success=True,
            pending=False,
            provider_reference='EXT-1',
            internal_reference='INT-1',
            merchant_reference='refresh_me',
            status='SUCCESS',
            response_body={'success': True, 'response_data': {'status': 'SUCCESS'}},
            message='ok',
        )
        with patch(
            'src.apps.payments.adapters.mm_aggregator.'
            'MmAggregatorPaymentAdapter.check_deposit_status',
            return_value=fake,
        ):
            res = self.api.post('/api/v1/payments/transactions/refresh_me/refresh/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['status']['value'], 'S')
        self.assertEqual(res.data['status_code'], 'S')
        txn.refresh_from_db()
        self.assertEqual(txn.status, PaymentTransaction.TransactionStatus.SUCCEEDED)
        self.assertEqual(txn.provider_reference, 'EXT-1')
