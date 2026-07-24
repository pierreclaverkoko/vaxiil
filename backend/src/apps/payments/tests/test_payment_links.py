"""Payment link creation, webhook, and redirect verification."""

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
from src.apps.finances.models import Currency
from src.apps.organizations.models import (
    Country,
    CountryAcceptedCurrency,
    Organization,
    OrganizationTypeModel,
)
from src.apps.payments.adapters.base import PaymentLinkResult
from src.apps.payments.models import PaymentProvider, PaymentTransaction
from src.apps.payments.services.signatures import hmac_sha256_hex
from src.apps.services.models import Service, ServiceCategory, ServiceSubCategory

User = get_user_model()


def _seed():
    cur, _ = Currency.objects.get_or_create(
        code='USD',
        defaults={
            'symbol': '$',
            'name': 'US Dollar',
            'numeric_code': '840',
            'minor_units': 2,
            'is_active': True,
        },
    )
    ctry, _ = Country.objects.get_or_create(
        iso_code2='US',
        defaults={
            'iso_code3': 'USA',
            'name': 'United States',
            'flag': '',
            'is_active': True,
        },
    )
    cac, _ = CountryAcceptedCurrency.objects.get_or_create(
        country=ctry,
        currency=cur,
        defaults={'is_active': True, 'is_default': True},
    )
    return ctry, cac, cur


@override_settings(
    MAINMONEY_WEBHOOK_SIGNING_SECRET='whsec_mainmoney_test',
    PAYMENT_REDIRECT_BASE_URL='http://localhost:3000',
)
class PaymentLinkApiTests(TestCase):
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
            name='Swedish',
            sub_category=sub,
            organization=cls.org,
            description='x',
            price_min=50,
            price_max=100,
            accepted_currency=cls.cac,
            address='1 Main',
            city='NYC',
            postal_code='10001',
            country_text='US',
            country=cls.country,
        )
        cls.provider = PaymentProvider.objects.create(
            code='mainmoney',
            provider_type=PaymentProvider.ProviderType.OTHER,
            display_name='MainMoney',
            is_active=True,
            config={'api_key': 'test', 'base_url': 'https://pay.example.test'},
        )
        start = timezone.now() + timedelta(days=3)
        cls.booking = Booking.objects.create(
            user=cls.customer,
            service=cls.service,
            organization=cls.org,
            status=Booking.BookingStatus.REQUESTED,
            total_price=Decimal('75.00'),
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
        self._link_patcher = patch(
            'src.apps.payments.adapters.mainmoney.MainmoneyPaymentAdapter.create_payment_link',
            return_value=PaymentLinkResult(
                url='https://pay.mainmoney.net/l/stub',
                link_id='pl_stub',
                slug='stub',
                merchant_reference='ignored',
                response_body={'data': {'url': 'https://pay.mainmoney.net/l/stub'}},
            ),
        )
        self.mock_create_link = self._link_patcher.start()
        self.addCleanup(self._link_patcher.stop)

    def test_create_payment_link_happy_path(self):
        self.api.force_authenticate(user=self.customer)
        res = self.api.post(
            f'/api/v1/payments/bookings/{self.booking.id}/payment-link/',
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertIn('url', res.data)
        self.assertTrue(res.data['merchant_reference'].startswith('bk_'))
        txn = PaymentTransaction.objects.get(id=res.data['transaction_id'])
        self.assertEqual(txn.status, PaymentTransaction.TransactionStatus.PROCESSING)
        self.assertEqual(txn.client_reference, res.data['merchant_reference'])
        self.assertEqual(txn.payment_provider.code, 'mainmoney')

    def test_create_payment_link_requires_active_mainmoney(self):
        self.provider.is_active = False
        self.provider.save(update_fields=['is_active'])
        self.api.force_authenticate(user=self.customer)
        res = self.api.post(
            f'/api/v1/payments/bookings/{self.booking.id}/payment-link/',
        )
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('payment_provider', res.data)

    def test_create_payment_link_forbidden_for_other_user(self):
        self.api.force_authenticate(user=self.other)
        res = self.api.post(
            f'/api/v1/payments/bookings/{self.booking.id}/payment-link/',
        )
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    def test_create_payment_link_allowed_when_rescheduled_unpaid(self):
        self.booking.status = Booking.BookingStatus.RESCHEDULED
        self.booking.save(update_fields=['status', 'updated_at'])
        self.api.force_authenticate(user=self.customer)
        res = self.api.post(
            f'/api/v1/payments/bookings/{self.booking.id}/payment-link/',
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED, res.data)
        self.assertIn('url', res.data)

    def test_webhook_completed_marks_paid_without_confirm(self):
        self.api.force_authenticate(user=self.customer)
        created = self.api.post(
            f'/api/v1/payments/bookings/{self.booking.id}/payment-link/',
        )
        ref = created.data['merchant_reference']
        payload = {
            'event': 'payment_link.payment.completed',
            'data': {
                'reference': ref,
                'paymentLinkId': 'pl_1',
                'slug': 'abc',
                'amount': 75,
                'currency': 'USD',
                'status': 'COMPLETED',
                'environment': 'SANDBOX',
            },
        }
        raw = json.dumps(payload).encode('utf-8')
        sig = hmac_sha256_hex('whsec_mainmoney_test', raw)

        res = self.api.post(
            '/api/v1/payments/webhooks/mainmoney/',
            data=raw,
            content_type='application/json',
            HTTP_X_MAINMONEY_SIGNATURE=sig,
            HTTP_X_MAINMONEY_EVENT='payment_link.payment.completed',
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.booking.refresh_from_db()
        # Payment does not auto-confirm; status stays Requested until business accepts.
        self.assertEqual(self.booking.status, Booking.BookingStatus.REQUESTED)
        txn = PaymentTransaction.objects.get(client_reference=ref)
        self.assertEqual(txn.status, PaymentTransaction.TransactionStatus.SUCCEEDED)

    def test_webhook_rejects_bad_signature(self):
        payload = {'event': 'payment_link.payment.completed', 'data': {'reference': 'x'}}
        raw = json.dumps(payload).encode('utf-8')
        res = self.api.post(
            '/api/v1/payments/webhooks/mainmoney/',
            data=raw,
            content_type='application/json',
            HTTP_X_MAINMONEY_SIGNATURE='deadbeef',
            HTTP_X_MAINMONEY_EVENT='payment_link.payment.completed',
        )
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

    def test_webhook_idempotent(self):
        self.api.force_authenticate(user=self.customer)
        created = self.api.post(
            f'/api/v1/payments/bookings/{self.booking.id}/payment-link/',
        )
        ref = created.data['merchant_reference']
        payload = {
            'event': 'payment_link.payment.completed',
            'data': {
                'reference': ref,
                'status': 'COMPLETED',
                'amount': 75,
                'currency': 'USD',
            },
        }
        raw = json.dumps(payload).encode('utf-8')
        sig = hmac_sha256_hex('whsec_mainmoney_test', raw)
        headers = {
            'HTTP_X_MAINMONEY_SIGNATURE': sig,
            'HTTP_X_MAINMONEY_EVENT': 'payment_link.payment.completed',
        }
        r1 = self.api.post(
            '/api/v1/payments/webhooks/mainmoney/',
            data=raw,
            content_type='application/json',
            **headers,
        )
        r2 = self.api.post(
            '/api/v1/payments/webhooks/mainmoney/',
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

    def test_redirect_verifies_and_forwards(self):
        self.api.force_authenticate(user=self.customer)
        created = self.api.post(
            f'/api/v1/payments/bookings/{self.booking.id}/payment-link/',
        )
        ref = created.data['merchant_reference']
        amount = '75'
        currency = 'USD'
        ts = '1718000000'
        status_s = 'completed'
        payload = f'{ref}|{status_s}|{amount}|{currency}|{ts}'
        sig = hmac_sha256_hex('whsec_mainmoney_test', payload)

        res = self.api.get(
            '/api/v1/payments/redirect/',
            {
                'reference': ref,
                'status': status_s,
                'amount': amount,
                'currency': currency,
                'timestamp': ts,
                'signature': sig,
            },
        )
        self.assertEqual(res.status_code, status.HTTP_302_FOUND)
        self.assertIn('/payment-return', res['Location'])
        self.booking.refresh_from_db()
        self.assertEqual(self.booking.status, Booking.BookingStatus.REQUESTED)

    def test_mainmoney_adapter_wired_for_provider(self):
        self.mock_create_link.return_value = PaymentLinkResult(
            url='https://pay.mainmoney.net/l/x',
            link_id='pl_x',
            slug='x',
            merchant_reference='will-be-overwritten',
            response_body={'data': {'url': 'https://pay.mainmoney.net/l/x'}},
        )
        self.api.force_authenticate(user=self.customer)
        res = self.api.post(
            f'/api/v1/payments/bookings/{self.booking.id}/payment-link/',
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res.data['url'], 'https://pay.mainmoney.net/l/x')
        self.mock_create_link.assert_called()


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
