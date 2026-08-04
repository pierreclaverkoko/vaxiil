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
from src.apps.finances.models import OrganizationRevenueLedger, OrganizationRevenueWallet
from src.apps.finances.services.inscription import (
    available_settlement_balance,
    credit_org_revenue,
)
from src.apps.finances.models import PlatformFeeEntry
from src.apps.finances.services.platform_fees import accrue_platform_fee_for_booking
from src.apps.organizations.models import (
    Organization,
    OrganizationMembership,
    OrganizationTypeModel,
)
from src.apps.payments.adapters.base import CollectResult
from src.apps.payments.catalog import PaymentConnector, PaymentMethod
from src.apps.payments.models import (
    PaymentProvider,
    PaymentTransaction,
    RefundWallet,
    RefundWalletLedger,
)
from src.apps.payments.services.signatures import hmac_sha256_hex
from src.apps.services.models import Service, ServiceCategory, ServiceSubCategory
from src.apps.test_helpers.geo import seed_cities_country, seed_us_country_and_currency

User = get_user_model()


def _seed():
    ctry, cac = seed_us_country_and_currency()
    return ctry, cac, cac.currency


@override_settings(
    PAYMENT_REDIRECT_BASE_URL='http://localhost:3000',
    MM_AGGREGATOR_WEBHOOK_SIGNING_SECRET='whsec_mma_test',
)
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
            verification_status=User.VerificationStatus.VERIFIED,
        )
        cls.customer.inscription_fee_paid_at = timezone.now()
        cls.customer.email_verified_at = timezone.now()
        cls.customer.save(
            update_fields=['inscription_fee_paid_at', 'email_verified_at']
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
            code='mm_aggregator',
            defaults={
                'provider_type': PaymentProvider.ProviderType.OTHER,
                'display_name': 'Secure payment',
                'is_active': True,
            },
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
            code='MOMO_WALLET_TEST',
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

    def setUp(self):
        self.api = APIClient()
        self.api.force_authenticate(user=self.customer)
        self._collect_patcher = patch(
            'src.apps.payments.adapters.mm_aggregator.MmAggregatorPaymentAdapter.collect',
            return_value=CollectResult(
                success=True,
                pending=True,
                provider_reference='dep_w',
                internal_reference='INTW',
                merchant_reference='ignored',
                status='PENDING',
                response_body={'data': {'status': 'PENDING'}},
            ),
        )
        self._collect_patcher.start()
        self.addCleanup(self._collect_patcher.stop)

    def _collect_body(self, **extra):
        body = {
            'payment_method_id': str(self.method.id),
            'account_identifier': '+254712345678',
        }
        body.update(extra)
        return body

    def _paid_booking(self, price='75.00'):
        start = timezone.now() + timedelta(days=7)
        booking = Booking.objects.create(
            user=self.customer,
            service=self.service,
            organization=self.org,
            status=Booking.BookingStatus.CONFIRMED,
            total_price=Decimal(price),
            base_price=Decimal(price),
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
        self.assertEqual(res.data['refund']['status'], 'refunded')
        self.assertEqual(res.data['booking']['payment_state'], 'refunded')
        self.assertFalse(res.data['booking']['is_paid'])

        refund_txn = PaymentTransaction.objects.get(
            booking=booking,
            kind__in=(
                PaymentTransaction.TransactionKind.REFUND,
                PaymentTransaction.TransactionKind.PARTIAL_REFUND,
            ),
        )
        self.assertEqual(
            refund_txn.status,
            PaymentTransaction.TransactionStatus.REFUNDED,
        )
        pay_txn = PaymentTransaction.objects.get(
            booking=booking,
            kind=PaymentTransaction.TransactionKind.PAYMENT,
        )
        self.assertEqual(
            pay_txn.status,
            PaymentTransaction.TransactionStatus.REFUNDED,
        )

        wallet_res = self.api.get('/api/v1/payments/wallet/')
        self.assertEqual(wallet_res.status_code, status.HTTP_200_OK)
        self.assertEqual(wallet_res.data['balances'][0]['currency_code'], 'USD')
        self.assertEqual(wallet_res.data['balances'][0]['balance'], '75.00')
        self.assertEqual(wallet_res.data['total_credited'], '75.00')

    def test_apply_wallet_reduces_collect_amount(self):
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
            base_price=Decimal('100.00'),
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
            self._collect_body(apply_wallet=True),
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED, res.data)
        self.assertEqual(res.data['wallet_applied'], '40.00')
        self.assertEqual(res.data['amount_charged'], '60.00')
        self.assertFalse(res.data['fully_paid'])
        self.assertEqual(
            RefundWallet.objects.get(user=self.customer).balance,
            Decimal('0.00'),
        )

    def test_full_wallet_payment_skips_collect(self):
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
            base_price=Decimal('50.00'),
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
        self.assertEqual(res.status_code, status.HTTP_201_CREATED, res.data)
        self.assertTrue(res.data['fully_paid'])
        self.assertIsNone(res.data.get('merchant_reference'))
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

    def test_wallet_top_up_credits_on_webhook(self):
        res = self.api.post(
            '/api/v1/payments/wallet/top-up/',
            {
                'amount': '25.00',
                'currency_code': 'USD',
                'payment_method_id': str(self.method.id),
                'account_identifier': '+254700000001',
            },
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED, res.data)
        ref = res.data['merchant_reference']
        self.assertTrue(ref.startswith('wt_'))

        txn = PaymentTransaction.objects.get(client_reference=ref)
        self.assertEqual(txn.purpose, PaymentTransaction.Purpose.WALLET_TOP_UP)
        self.assertIsNone(txn.booking_id)

        import json

        payload = {
            'type': 'DEPOSIT',
            'merchant_reference': ref,
            'status': 'SUCCESS',
            'amount': '25.00',
            'currency': 'USD',
        }
        raw = json.dumps(payload).encode('utf-8')
        sig = hmac_sha256_hex('whsec_mma_test', raw)
        wh = self.api.post(
            '/api/v1/payments/webhooks/mm_aggregator/',
            data=raw,
            content_type='application/json',
            HTTP_X_MMA_SIGNATURE=sig,
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

    def test_cancel_debits_merchant_and_does_not_reverse_platform_fee(self):
        booking = self._paid_booking('100.00')
        booking.platform_fee_amount = Decimal('1.00')
        booking.platform_fee_payer = Booking.PlatformFeePayer.CLIENT
        booking.total_price = Decimal('101.00')
        booking.save(
            update_fields=[
                'platform_fee_amount',
                'platform_fee_payer',
                'total_price',
            ]
        )
        PaymentTransaction.objects.filter(booking=booking).update(amount=Decimal('101.00'))
        credit_org_revenue(
            organization=self.org,
            currency=self.currency,
            amount=Decimal('100.00'),
            kind=OrganizationRevenueLedger.Kind.BOOKING_CREDIT,
            booking=booking,
            idempotency_key=f'test-credit-{booking.pk}',
        )
        accrue_platform_fee_for_booking(booking)

        res = self.api.post(
            f'/api/v1/bookings/{booking.id}/cancel/',
            {'reason': 'early cancel'},
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['refund']['amount'], '101.00')
        self.assertFalse(res.data['refund']['penalty_applies'])
        self.assertEqual(
            PlatformFeeEntry.objects.filter(
                booking=booking,
                status=PlatformFeeEntry.EntryStatus.REVERSED,
            ).count(),
            0,
        )
        self.assertTrue(
            OrganizationRevenueLedger.objects.filter(
                booking=booking,
                kind=OrganizationRevenueLedger.Kind.CANCELLATION_DEBIT,
                amount=Decimal('-101.00'),
            ).exists()
        )
        wallet = OrganizationRevenueWallet.objects.get(
            organization=self.org,
            currency=self.currency,
        )
        self.assertEqual(wallet.balance, Decimal('-1.00'))

    def test_late_client_cancel_applies_50_percent_and_platform_share(self):
        start = timezone.now() + timedelta(hours=12)
        booking = Booking.objects.create(
            user=self.customer,
            service=self.service,
            organization=self.org,
            status=Booking.BookingStatus.CONFIRMED,
            total_price=Decimal('100.00'),
            base_price=Decimal('100.00'),
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
            amount=Decimal('100.00'),
            currency=self.currency,
            kind=PaymentTransaction.TransactionKind.PAYMENT,
            status=PaymentTransaction.TransactionStatus.SUCCEEDED,
            provider_reference=f'pay_late_{booking.pk}',
        )
        credit_org_revenue(
            organization=self.org,
            currency=self.currency,
            amount=Decimal('100.00'),
            kind=OrganizationRevenueLedger.Kind.BOOKING_CREDIT,
            booking=booking,
            idempotency_key=f'test-late-credit-{booking.pk}',
        )

        res = self.api.post(
            f'/api/v1/bookings/{booking.id}/cancel/',
            {'reason': 'late'},
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['refund']['amount'], '50.00')
        self.assertTrue(res.data['refund']['penalty_applies'])
        self.assertEqual(res.data['refund']['platform_penalty_amount'], '10.00')
        self.assertEqual(res.data['booking']['payment_state'], 'refunded')
        self.assertFalse(res.data['booking']['is_paid'])
        partial = PaymentTransaction.objects.get(
            booking=booking,
            kind=PaymentTransaction.TransactionKind.PARTIAL_REFUND,
        )
        self.assertEqual(
            partial.status,
            PaymentTransaction.TransactionStatus.REFUNDED,
        )
        # Net still > 0 after 50% refund — original payment stays Succeeded.
        pay_txn = PaymentTransaction.objects.get(
            booking=booking,
            kind=PaymentTransaction.TransactionKind.PAYMENT,
        )
        self.assertEqual(
            pay_txn.status,
            PaymentTransaction.TransactionStatus.SUCCEEDED,
        )
        self.assertEqual(
            RefundWallet.objects.get(user=self.customer).balance,
            Decimal('50.00'),
        )
        self.assertTrue(
            OrganizationRevenueLedger.objects.filter(
                booking=booking,
                kind=OrganizationRevenueLedger.Kind.CANCELLATION_PENALTY,
                amount=Decimal('-10.00'),
            ).exists()
        )
        wallet = OrganizationRevenueWallet.objects.get(
            organization=self.org,
            currency=self.currency,
        )
        # 100 credit - 50 client refund - 10 platform share = 40 kept by merchant
        self.assertEqual(wallet.balance, Decimal('40.00'))

    def test_settlement_holds_non_completed_booking_revenue(self):
        booking = self._paid_booking('80.00')
        credit_org_revenue(
            organization=self.org,
            currency=self.currency,
            amount=Decimal('80.00'),
            kind=OrganizationRevenueLedger.Kind.BOOKING_CREDIT,
            booking=booking,
            idempotency_key=f'test-hold-{booking.pk}',
        )
        wallet = OrganizationRevenueWallet.objects.get(
            organization=self.org,
            currency=self.currency,
        )
        self.assertEqual(available_settlement_balance(wallet), Decimal('0.00'))
        booking.status = Booking.BookingStatus.COMPLETED
        booking.save(update_fields=['status'])
        self.assertEqual(available_settlement_balance(wallet), Decimal('80.00'))

    def test_merchant_cancel_full_refund(self):
        owner = User.objects.create_user(
            email='owner-cancel@example.com',
            username='ownercancel',
            password='pass12345',
        )
        OrganizationMembership.objects.create(
            organization=self.org,
            user=owner,
            role=OrganizationMembership.OrganizationMemberRole.OWNER,
        )
        booking = self._paid_booking('60.00')
        credit_org_revenue(
            organization=self.org,
            currency=self.currency,
            amount=Decimal('60.00'),
            kind=OrganizationRevenueLedger.Kind.BOOKING_CREDIT,
            booking=booking,
            idempotency_key=f'test-merch-{booking.pk}',
        )
        # Late slot — merchant cancel still full refund
        slot = booking.time_slots.first()
        slot.start_time = timezone.now() + timedelta(hours=6)
        slot.end_time = slot.start_time + timedelta(hours=1)
        slot.save(update_fields=['start_time', 'end_time'])

        self.api.force_authenticate(user=owner)
        res = self.api.post(
            f'/api/v1/bookings/{booking.id}/cancel/',
            {'reason': 'staff cancel'},
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK, res.data)
        self.assertEqual(res.data['refund']['amount'], '60.00')
        self.assertFalse(res.data['refund']['penalty_applies'])
        self.assertEqual(
            RefundWallet.objects.get(user=self.customer).balance,
            Decimal('60.00'),
        )
