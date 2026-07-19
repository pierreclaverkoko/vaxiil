"""Refund wallet credit on cancel and apply at payment-link creation."""

from __future__ import annotations

from datetime import timedelta
from decimal import Decimal
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APIClient

from src.apps.bookings.cancellation_models import CancellationPolicy
from src.apps.bookings.models import Booking, BookingTimeSlot
from src.apps.finances.models import Currency
from src.apps.organizations.models import (
    Country,
    CountryAcceptedCurrency,
    Organization,
    OrganizationTypeModel,
)
from src.apps.payments.adapters.base import PaymentLinkResult
from src.apps.payments.models import (
    PaymentProvider,
    PaymentTransaction,
    RefundWallet,
    RefundWalletLedger,
)
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


@override_settings(PAYMENT_REDIRECT_BASE_URL='http://localhost:3000')
class RefundWalletApiTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.country, cls.cac, cls.currency = _seed()
        cls.org_type = OrganizationTypeModel.objects.create(
            name='spa',
            display_name='Spa',
        )
        cls.customer = User.objects.create_user(
            email='wallet@example.com',
            username='walletuser',
            password='pass12345',
        )
        cls.org = Organization.objects.create(
            name='Wallet Org',
            type=cls.org_type,
            email='wallet-org@example.com',
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
            code='stub-wallet',
            provider_type=PaymentProvider.ProviderType.OTHER,
            display_name='Stub',
            is_active=True,
        )
        CancellationPolicy.objects.create(
            organization=cls.org,
            name='Default',
            policy_type=CancellationPolicy.PolicyType.FLEXIBLE,
            description='test',
            full_refund_hours=48,
            cancellation_windows={},
        )
        PaymentProvider.objects.get_or_create(
            code='mainmoney',
            defaults={
                'provider_type': PaymentProvider.ProviderType.CARD,
                'display_name': 'MainMoney',
                'is_active': True,
            },
        )

    def setUp(self):
        self.api = APIClient()
        self.api.force_authenticate(user=self.customer)

    def _paid_booking(self, price='75.00'):
        start = timezone.now() + timedelta(days=7)
        booking = Booking.objects.create(
            user=self.customer,
            service=self.service,
            organization=self.org,
            status=Booking.BookingStatus.CONFIRMED,
            total_price=Decimal(price),
            accepted_currency=self.cac,
        )
        BookingTimeSlot.objects.create(
            booking=booking,
            start_time=start,
            end_time=start + timedelta(hours=1),
            location_type=Booking.LocationType.OFFICE,
        )
        PaymentTransaction.objects.create(
            booking=booking,
            payment_provider=self.provider,
            user=self.customer,
            amount=Decimal(price),
            currency=self.currency,
            kind=PaymentTransaction.TransactionKind.PAYMENT,
            status=PaymentTransaction.TransactionStatus.SUCCEEDED,
            provider_reference=f'pay_{booking.pk}',
        )
        return booking

    def test_cancel_credits_refund_wallet(self):
        booking = self._paid_booking()
        res = self.api.post(
            f'/api/v1/bookings/{booking.id}/cancel/',
            {'reason': 'changed plans'},
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['refund']['destination'], 'wallet')
        self.assertEqual(res.data['refund']['amount'], '75.00')

        wallet_res = self.api.get('/api/v1/payments/wallet/')
        self.assertEqual(wallet_res.status_code, status.HTTP_200_OK)
        self.assertEqual(wallet_res.data['balances'][0]['currency_code'], 'USD')
        self.assertEqual(wallet_res.data['balances'][0]['balance'], '75.00')
        self.assertEqual(wallet_res.data['total_credited'], '75.00')

    @patch(
        'src.apps.payments.adapters.mainmoney.MainmoneyPaymentAdapter.create_payment_link',
        return_value=PaymentLinkResult(
            url='https://pay.example/link',
            link_id='lnk_1',
            slug='slug_1',
            merchant_reference='ignored',
            response_body={},
        ),
    )
    def test_apply_wallet_reduces_payment_link_amount(self, _mock):
        cancelled = self._paid_booking('40.00')
        self.api.post(
            f'/api/v1/bookings/{cancelled.id}/cancel/',
            {'reason': 'cancel'},
            format='json',
        )
        self.assertEqual(
            RefundWallet.objects.get(user=self.customer).balance,
            Decimal('40.00'),
        )

        start = timezone.now() + timedelta(days=10)
        unpaid = Booking.objects.create(
            user=self.customer,
            service=self.service,
            organization=self.org,
            status=Booking.BookingStatus.REQUESTED,
            total_price=Decimal('100.00'),
            accepted_currency=self.cac,
        )
        BookingTimeSlot.objects.create(
            booking=unpaid,
            start_time=start,
            end_time=start + timedelta(hours=1),
            location_type=Booking.LocationType.OFFICE,
        )

        res = self.api.post(
            f'/api/v1/payments/bookings/{unpaid.id}/payment-link/',
            {'apply_wallet': True},
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res.data['wallet_applied'], '40.00')
        self.assertEqual(res.data['amount_charged'], '60.00')
        self.assertFalse(res.data['fully_paid'])
        self.assertEqual(
            RefundWallet.objects.get(user=self.customer).balance,
            Decimal('0.00'),
        )

    def test_full_wallet_payment_skips_payment_link(self):
        cancelled = self._paid_booking('80.00')
        self.api.post(
            f'/api/v1/bookings/{cancelled.id}/cancel/',
            {'reason': 'cancel'},
            format='json',
        )

        start = timezone.now() + timedelta(days=10)
        unpaid = Booking.objects.create(
            user=self.customer,
            service=self.service,
            organization=self.org,
            status=Booking.BookingStatus.REQUESTED,
            total_price=Decimal('50.00'),
            accepted_currency=self.cac,
        )
        BookingTimeSlot.objects.create(
            booking=unpaid,
            start_time=start,
            end_time=start + timedelta(hours=1),
            location_type=Booking.LocationType.OFFICE,
        )

        res = self.api.post(
            f'/api/v1/payments/bookings/{unpaid.id}/payment-link/',
            {'apply_wallet': True},
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertTrue(res.data['fully_paid'])
        self.assertIsNone(res.data['url'])
        self.assertEqual(res.data['wallet_applied'], '50.00')
        self.assertEqual(
            RefundWallet.objects.get(user=self.customer).balance,
            Decimal('30.00'),
        )

    def test_wallet_summary_includes_zero_when_empty(self):
        res = self.api.get('/api/v1/payments/wallet/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res.data['balances']), 1)
        self.assertEqual(res.data['balances'][0]['balance'], '0.00')

    @patch(
        'src.apps.payments.adapters.mainmoney.MainmoneyPaymentAdapter.create_payment_link',
        return_value=PaymentLinkResult(
            url='https://pay.example/topup',
            link_id='lnk_top',
            slug='slug_top',
            merchant_reference='ignored',
            response_body={},
        ),
    )
    @override_settings(MAINMONEY_WEBHOOK_SIGNING_SECRET='whsec_mainmoney_test')
    def test_wallet_top_up_credits_on_webhook(self, _mock):
        res = self.api.post(
            '/api/v1/payments/wallet/top-up/',
            {'amount': '25.00', 'currency_code': 'USD'},
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res.data['url'], 'https://pay.example/topup')
        ref = res.data['merchant_reference']
        self.assertTrue(ref.startswith('wt_'))

        txn = PaymentTransaction.objects.get(client_reference=ref)
        self.assertEqual(txn.purpose, PaymentTransaction.Purpose.WALLET_TOP_UP)
        self.assertIsNone(txn.booking_id)

        import json

        payload = {
            'event': 'payment_link.payment.completed',
            'data': {
                'reference': ref,
                'amount': 25,
                'currency': 'USD',
                'status': 'COMPLETED',
            },
        }
        raw = json.dumps(payload).encode('utf-8')
        sig = hmac_sha256_hex('whsec_mainmoney_test', raw)
        wh = self.api.post(
            '/api/v1/payments/webhooks/mainmoney/',
            data=raw,
            content_type='application/json',
            HTTP_X_MAINMONEY_SIGNATURE=sig,
            HTTP_X_MAINMONEY_EVENT='payment_link.payment.completed',
        )
        self.assertEqual(wh.status_code, status.HTTP_200_OK)
        wallet = RefundWallet.objects.get(user=self.customer, currency=self.cac.currency)
        self.assertEqual(wallet.balance, Decimal('25.00'))
        self.assertTrue(
            RefundWalletLedger.objects.filter(
                wallet=wallet,
                kind=RefundWalletLedger.Kind.TOP_UP,
            ).exists()
        )
