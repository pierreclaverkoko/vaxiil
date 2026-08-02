"""Inscription fee, annual subscription, FX, and settlement basics."""

from __future__ import annotations

from datetime import timedelta
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APIClient

from src.apps.bookings.models import Booking
from src.apps.finances.models import (
    Currency,
    CurrencyFxRate,
    OrganizationRevenueWallet,
    PlatformSettings,
    SettlementAccount,
    SettlementRequest,
)
from src.apps.finances.services.fx import usd_to_currency
from src.apps.finances.services.inscription import (
    apply_booking_payment_revenue,
    inscription_fee_due_for_user,
    mark_inscription_paid,
)
from src.apps.finances.services.settlement import create_manual_settlement_request
from src.apps.organizations.models import (
    Organization,
    OrganizationMembership,
    OrganizationSettings,
    OrganizationTypeModel,
)
from src.apps.payments.catalog_seed import ensure_default_payment_catalog
from src.apps.payments.catalog import PaymentMethod
from src.apps.test_helpers.geo import seed_us_country_and_currency

User = get_user_model()


class FxAndInscriptionTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        _country, cls.cac = seed_us_country_and_currency()
        cls.usd = cls.cac.currency
        cls.cdf, _ = Currency.objects.get_or_create(
            code='CDF',
            defaults={
                'symbol': 'FC',
                'name': 'Congolese Franc',
                'numeric_code': '976',
                'minor_units': 2,
                'is_active': True,
            },
        )
        CurrencyFxRate.objects.create(
            from_currency=cls.usd,
            to_currency=cls.cdf,
            rate=Decimal('2800'),
            effective_at=timezone.now() - timedelta(days=1),
        )
        PlatformSettings.get_solo()

    def test_usd_to_currency_uses_latest_rate(self):
        local = usd_to_currency(Decimal('5.00'), self.cdf)
        self.assertEqual(local, Decimal('14000.00'))

    def test_inscription_due_once(self):
        user = User.objects.create_user(
            email='insc@example.com', username='insc', password='x'
        )
        due = inscription_fee_due_for_user(user=user, currency=self.usd)
        self.assertEqual(due, Decimal('5.00'))
        mark_inscription_paid(
            user=user,
            currency=self.usd,
            amount=Decimal('5.00'),
            usd_amount=Decimal('5.00'),
        )
        user.refresh_from_db()
        self.assertIsNotNone(user.inscription_fee_paid_at)
        self.assertEqual(
            inscription_fee_due_for_user(user=user, currency=self.usd),
            Decimal('0.00'),
        )


class AnnualSubscriptionNegativeBalanceTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        _country, cls.cac = seed_us_country_and_currency()
        cls.usd = cls.cac.currency
        PlatformSettings.get_solo()
        cls.org_type = OrganizationTypeModel.objects.create(name='Spa')
        cls.org = Organization.objects.create(
            name='Fee Org',
            type=cls.org_type,
            email='feeorg@example.com',
        )
        OrganizationSettings.objects.create(organization=cls.org)
        cls.owner = User.objects.create_user(
            email='feeowner@example.com',
            username='feeowner',
            password='x',
            verification_status=User.VerificationStatus.VERIFIED,
        )
        OrganizationMembership.objects.create(
            organization=cls.org,
            user=cls.owner,
            role=OrganizationMembership.OrganizationMemberRole.OWNER,
        )
        from src.apps.services.models import Service, ServiceCategory, ServiceSubCategory
        from src.apps.test_helpers.geo import seed_cities_country

        cat = ServiceCategory.objects.create(name='Massage')
        sub = ServiceSubCategory.objects.create(category=cat, name='Swedish')
        cls.service = Service.objects.create(
            cities_city=seed_cities_country(city_name='FeeCity')[1],
            name='Relax',
            sub_category=sub,
            organization=cls.org,
            description='x',
            price_min=8,
            price_max=8,
            accepted_currency=cls.cac,
            address='1 Main',
            postal_code='10001',
            country_text='US',
            country=_country,
        )

    def test_annual_fee_can_drive_balance_negative(self):
        booking = Booking.objects.create(
            user=self.owner,
            organization=self.org,
            service=self.service,
            status=Booking.BookingStatus.REQUESTED,
            base_price=Decimal('8.00'),
            platform_fee_amount=Decimal('0'),
            platform_fee_payer='C',
            total_price=Decimal('8.00'),
            accepted_currency=self.cac,
        )
        apply_booking_payment_revenue(booking=booking)
        wallet = OrganizationRevenueWallet.objects.get(
            organization=self.org, currency=self.usd
        )
        self.assertEqual(wallet.balance, Decimal('-7.00'))
        settings_row = OrganizationSettings.objects.get(organization=self.org)
        self.assertIsNotNone(settings_row.annual_fee_paid_through)


class SettlementApiTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        _country, cls.cac = seed_us_country_and_currency()
        cls.usd = cls.cac.currency
        PlatformSettings.get_solo()
        cls.org_type = OrganizationTypeModel.objects.create(name='Clinic')
        cls.org = Organization.objects.create(
            name='Settle Org',
            type=cls.org_type,
            email='settle@example.com',
        )
        OrganizationSettings.objects.create(organization=cls.org)
        cls.owner = User.objects.create_user(
            email='settleowner@example.com',
            username='settleowner',
            password='x',
        )
        OrganizationMembership.objects.create(
            organization=cls.org,
            user=cls.owner,
            role=OrganizationMembership.OrganizationMemberRole.OWNER,
        )
        OrganizationRevenueWallet.objects.create(
            organization=cls.org,
            currency=cls.usd,
            balance=Decimal('50.00'),
        )
        ensure_default_payment_catalog()
        cls.account = SettlementAccount.objects.create(
            organization=cls.org,
            method=PaymentMethod.objects.get(code='INTERAC_CA'),
            account_identifier='payout@example.com',
            account_name='Settle Owner',
            is_default=True,
        )

    def test_manual_settlement_and_staff_serializer_hides_image_from_business(self):
        req = create_manual_settlement_request(
            organization=self.org,
            amount=Decimal('20.00'),
            currency=self.usd,
            account=self.account,
            requested_by=self.owner,
        )
        self.assertEqual(req.status, SettlementRequest.Status.REQUESTED)
        wallet = OrganizationRevenueWallet.objects.get(
            organization=self.org, currency=self.usd
        )
        self.assertEqual(wallet.balance, Decimal('30.00'))

        api = APIClient()
        api.force_authenticate(user=self.owner)
        res = api.get(f'/api/v1/organizations/{self.org.pk}/settlement/requests/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertNotIn('confirmation_image', res.data[0])
        self.assertNotIn('confirmation_image_url', res.data[0])
