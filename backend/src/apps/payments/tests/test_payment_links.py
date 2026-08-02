"""Collection (mm_aggregator), webhook, and redirect verification tests."""

from __future__ import annotations

import hashlib
import hmac
import json
from datetime import timedelta
from decimal import Decimal
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.test import SimpleTestCase, TestCase, override_settings
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APIClient

from src.apps.bookings.models import Booking, BookingTimeSlot
from src.apps.organizations.models import Organization, OrganizationTypeModel
from src.apps.payments.adapters.base import CollectResult
from src.apps.payments.catalog import PaymentConnector, PaymentMethod
from src.apps.payments.models import PaymentProvider, PaymentTransaction
from src.apps.payments.services.signatures import hmac_sha256_hex
from src.apps.services.models import Service, ServiceCategory, ServiceSubCategory
from src.apps.test_helpers.geo import seed_cities_country, seed_us_country_and_currency

User = get_user_model()


def _seed():
    ctry, cac = seed_us_country_and_currency()
    return ctry, cac, cac.currency


@override_settings(
    MAINMONEY_WEBHOOK_SIGNING_SECRET='whsec_mainmoney_test',
    MM_AGGREGATOR_WEBHOOK_SIGNING_SECRET='whsec_mma_test',
    PAYMENT_REDIRECT_BASE_URL='http://localhost:3000',
)
class CollectPaymentApiTests(TestCase):
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
            config={
                'destination_fields': ['phone_number'],
                'provider_code': 'MPESA_KE',
            },
            supported_operations=[
                PaymentMethod.Operation.COLLECT,
                PaymentMethod.Operation.WALLET_FUND,
            ],
            is_active=True,
        )
        start = timezone.now() + timedelta(days=3)
        cls.booking = Booking.objects.create(
            user=cls.customer,
            service=cls.service,
            organization=cls.org,
            status=Booking.BookingStatus.REQUESTED,
            total_price=Decimal('75.00'),
            base_price=Decimal('75.00'),
            accepted_currency=cls.cac,
        )
        BookingTimeSlot.objects.create(
            booking=cls.booking,
            start_time=start,
            end_time=start + timedelta(hours=1),
            location_type=Booking.LocationType.OFFICE,
        )

    def setUp(self):
        self.api = APIClient()
        self._collect_patcher = patch(
            'src.apps.payments.adapters.mm_aggregator.MmAggregatorPaymentAdapter.collect',
            return_value=CollectResult(
                success=True,
                pending=True,
                provider_reference='dep_1',
                internal_reference='INT1',
                merchant_reference='ignored',
                status='PENDING',
                response_body={'data': {'status': 'PENDING'}},
                message='pending',
            ),
        )
        self.mock_collect = self._collect_patcher.start()
        self.addCleanup(self._collect_patcher.stop)

    def _collect_body(self, **extra):
        body = {
            'payment_method_id': str(self.method.id),
            'account_identifier': '+254712345678',
        }
        body.update(extra)
        return body

    def test_collect_happy_path(self):
        self.api.force_authenticate(user=self.customer)
        res = self.api.post(
            f'/api/v1/payments/bookings/{self.booking.id}/payment-link/',
            self._collect_body(),
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED, res.data)
        self.assertNotIn('url', res.data)
        self.assertTrue(res.data['merchant_reference'].startswith('bk_'))
        txn = PaymentTransaction.objects.get(id=res.data['transaction_id'])
        self.assertEqual(txn.status, PaymentTransaction.TransactionStatus.PROCESSING)
        self.assertEqual(txn.client_reference, res.data['merchant_reference'])
        self.assertEqual(txn.payment_provider.code, 'mm_aggregator')
        self.mock_collect.assert_called()

    def test_collect_requires_active_provider(self):
        self.provider.is_active = False
        self.provider.save(update_fields=['is_active'])
        self.api.force_authenticate(user=self.customer)
        res = self.api.post(
            f'/api/v1/payments/bookings/{self.booking.id}/payment-link/',
            self._collect_body(),
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('payment_provider', res.data)

    def test_collect_requires_method(self):
        self.api.force_authenticate(user=self.customer)
        res = self.api.post(
            f'/api/v1/payments/bookings/{self.booking.id}/payment-link/',
            {'account_identifier': '+254712345678'},
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('payment_method_id', res.data)

    def test_collect_forbidden_for_other_user(self):
        self.api.force_authenticate(user=self.other)
        res = self.api.post(
            f'/api/v1/payments/bookings/{self.booking.id}/payment-link/',
            self._collect_body(),
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    def test_collect_allowed_when_rescheduled_unpaid(self):
        self.booking.status = Booking.BookingStatus.RESCHEDULED
        self.booking.save(update_fields=['status', 'updated_at'])
        self.api.force_authenticate(user=self.customer)
        res = self.api.post(
            f'/api/v1/payments/bookings/{self.booking.id}/payment-link/',
            self._collect_body(),
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED, res.data)

    def test_mma_webhook_completed_marks_paid(self):
        self.api.force_authenticate(user=self.customer)
        created = self.api.post(
            f'/api/v1/payments/bookings/{self.booking.id}/payment-link/',
            self._collect_body(),
            format='json',
        )
        ref = created.data['merchant_reference']
        payload = {
            'type': 'DEPOSIT',
            'merchant_reference': ref,
            'status': 'SUCCESS',
            'amount': '75.00',
            'currency': 'USD',
        }
        raw = json.dumps(payload).encode('utf-8')
        sig = hmac_sha256_hex('whsec_mma_test', raw)

        res = self.api.post(
            '/api/v1/payments/webhooks/mm_aggregator/',
            data=raw,
            content_type='application/json',
            HTTP_X_MMA_SIGNATURE=sig,
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK, res.data)
        self.booking.refresh_from_db()
        self.assertEqual(self.booking.status, Booking.BookingStatus.REQUESTED)
        txn = PaymentTransaction.objects.get(client_reference=ref)
        self.assertEqual(txn.status, PaymentTransaction.TransactionStatus.SUCCEEDED)

    def test_mma_webhook_rejects_bad_signature(self):
        payload = {'merchant_reference': 'x', 'status': 'SUCCESS', 'type': 'DEPOSIT'}
        raw = json.dumps(payload).encode('utf-8')
        res = self.api.post(
            '/api/v1/payments/webhooks/mm_aggregator/',
            data=raw,
            content_type='application/json',
            HTTP_X_MMA_SIGNATURE='deadbeef',
        )
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

    def test_mma_webhook_idempotent(self):
        self.api.force_authenticate(user=self.customer)
        created = self.api.post(
            f'/api/v1/payments/bookings/{self.booking.id}/payment-link/',
            self._collect_body(),
            format='json',
        )
        ref = created.data['merchant_reference']
        payload = {
            'type': 'DEPOSIT',
            'merchant_reference': ref,
            'status': 'SUCCESS',
        }
        raw = json.dumps(payload).encode('utf-8')
        sig = hmac_sha256_hex('whsec_mma_test', raw)
        headers = {'HTTP_X_MMA_SIGNATURE': sig}
        r1 = self.api.post(
            '/api/v1/payments/webhooks/mm_aggregator/',
            data=raw,
            content_type='application/json',
            **headers,
        )
        r2 = self.api.post(
            '/api/v1/payments/webhooks/mm_aggregator/',
            data=raw,
            content_type='application/json',
            **headers,
        )
        self.assertEqual(r1.status_code, status.HTTP_200_OK)
        self.assertEqual(r2.status_code, status.HTTP_200_OK)
        self.assertEqual(
            PaymentTransaction.objects.filter(
                client_reference=ref,
                status=PaymentTransaction.TransactionStatus.SUCCEEDED,
            ).count(),
            1,
        )

    def test_wallet_top_up_collect(self):
        self.api.force_authenticate(user=self.customer)
        res = self.api.post(
            '/api/v1/payments/wallet/top-up/',
            {
                'amount': '20.00',
                'currency_code': self.currency.code,
                'payment_method_id': str(self.method.id),
                'account_identifier': '+254700000001',
            },
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED, res.data)
        self.assertTrue(res.data['merchant_reference'].startswith('wt_'))
        self.assertNotIn('url', res.data)


class SignatureHelperTests(SimpleTestCase):
    def test_hmac_hex(self):
        digest = hmac_sha256_hex('secret', 'a|b|c')
        expected = hmac.new(
            b'secret',
            b'a|b|c',
            hashlib.sha256,
        ).hexdigest()
        self.assertEqual(digest, expected)

    def test_redirect_signature_roundtrip(self):
        from src.apps.payments.services.signatures import verify_redirect_signature

        secret = 'whsec_mainmoney_test'
        reference = 'bk_1_abc'
        status_s = 'completed'
        amount = '75'
        currency = 'USD'
        ts = '1718000000'
        payload = f'{reference}|{status_s}|{amount}|{currency}|{ts}'
        sig = hmac_sha256_hex(secret, payload)
        self.assertTrue(
            verify_redirect_signature(
                secret=secret,
                reference=reference,
                status=status_s,
                amount=amount,
                currency=currency,
                timestamp=ts,
                signature=sig,
            )
        )
        self.assertFalse(
            verify_redirect_signature(
                secret=secret,
                reference=reference,
                status=status_s,
                amount=amount,
                currency=currency,
                timestamp=ts,
                signature='00' * 32,
            )
        )
