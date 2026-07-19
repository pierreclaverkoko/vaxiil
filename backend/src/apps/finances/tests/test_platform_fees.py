"""Platform fee resolve/compute, ledger, and staff fee APIs."""

from __future__ import annotations

from datetime import timedelta
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APIClient

from src.apps.bookings.models import Booking, BookingTimeSlot
from src.apps.finances.models import (
    CategoryPlatformFee,
    Currency,
    PlatformFeeEntry,
    PlatformSettings,
)
from src.apps.finances.services.platform_fees import (
    accrue_platform_fee_for_booking,
    compute_platform_fee,
    resolve_platform_fee,
    reverse_platform_fee_for_booking,
)
from src.apps.organizations.models import (
    Country,
    CountryAcceptedCurrency,
    Organization,
    OrganizationSettings,
    OrganizationTypeModel,
)
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


class PlatformFeeResolveTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.country, cls.cac, cls.currency = _seed()
        PlatformSettings.objects.update_or_create(
            pk=1,
            defaults={'platform_fee_rate': Decimal('1.00')},
        )
        cls.org_type = OrganizationTypeModel.objects.create(
            name='spa',
            display_name='Spa',
        )
        cls.org = Organization.objects.create(
            name='Fee Org',
            type=cls.org_type,
            email='fee@example.com',
            country=cls.country,
            default_currency=cls.cac,
        )
        OrganizationSettings.objects.get_or_create(organization=cls.org)
        cls.cat = ServiceCategory.objects.create(name='Massage')
        cls.sub = ServiceSubCategory.objects.create(name='Swedish', category=cls.cat)
        cls.service = Service.objects.create(
            name='Swedish',
            sub_category=cls.sub,
            organization=cls.org,
            description='x',
            price_min=100,
            price_max=100,
            accepted_currency=cls.cac,
        )

    def test_global_default_rate(self):
        resolved = resolve_platform_fee(organization=self.org, service=self.service)
        self.assertEqual(resolved.rate, Decimal('1.00'))
        self.assertEqual(resolved.source, PlatformFeeEntry.FeeSource.GLOBAL)

    def test_category_override_beats_global(self):
        CategoryPlatformFee.objects.create(category=self.cat, rate=Decimal('2.50'))
        resolved = resolve_platform_fee(organization=self.org, service=self.service)
        self.assertEqual(resolved.rate, Decimal('2.50'))
        self.assertEqual(resolved.source, PlatformFeeEntry.FeeSource.CATEGORY)

    def test_org_override_beats_category(self):
        CategoryPlatformFee.objects.create(category=self.cat, rate=Decimal('2.50'))
        settings_row = self.org.settings
        settings_row.platform_fee_rate = Decimal('5.00')
        settings_row.save()
        resolved = resolve_platform_fee(organization=self.org, service=self.service)
        self.assertEqual(resolved.rate, Decimal('5.00'))
        self.assertEqual(resolved.source, PlatformFeeEntry.FeeSource.ORGANIZATION)

    def test_client_payer_adds_fee_to_total(self):
        computed = compute_platform_fee(
            base_price=Decimal('100.00'),
            organization=self.org,
            service=self.service,
        )
        self.assertEqual(computed.fee_amount, Decimal('1.00'))
        self.assertEqual(computed.total_price, Decimal('101.00'))
        self.assertEqual(computed.base_price, Decimal('100.00'))

    def test_business_payer_keeps_client_total_at_base(self):
        settings_row = self.org.settings
        settings_row.platform_fee_payer = OrganizationSettings.PlatformFeePayer.BUSINESS
        settings_row.save()
        computed = compute_platform_fee(
            base_price=Decimal('100.00'),
            organization=self.org,
            service=self.service,
        )
        self.assertEqual(computed.fee_amount, Decimal('1.00'))
        self.assertEqual(computed.total_price, Decimal('100.00'))


class PlatformFeeLedgerTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.country, cls.cac, cls.currency = _seed()
        PlatformSettings.objects.update_or_create(
            pk=1,
            defaults={'platform_fee_rate': Decimal('1.00')},
        )
        cls.org_type = OrganizationTypeModel.objects.create(
            name='spa2',
            display_name='Spa',
        )
        cls.user = User.objects.create_user(
            email='client@example.com',
            username='client',
            password='pass12345',
        )
        cls.org = Organization.objects.create(
            name='Ledger Org',
            type=cls.org_type,
            email='ledger@example.com',
            country=cls.country,
            default_currency=cls.cac,
        )
        OrganizationSettings.objects.get_or_create(organization=cls.org)
        cat = ServiceCategory.objects.create(name='Yoga')
        sub = ServiceSubCategory.objects.create(name='Vinyasa', category=cat)
        cls.service = Service.objects.create(
            name='Yoga',
            sub_category=sub,
            organization=cls.org,
            description='x',
            price_min=100,
            price_max=100,
            accepted_currency=cls.cac,
        )

    def _booking(self):
        start = timezone.now() + timedelta(days=2)
        booking = Booking.objects.create(
            user=self.user,
            service=self.service,
            organization=self.org,
            status=Booking.BookingStatus.CONFIRMED,
            accepted_currency=self.cac,
            base_price=Decimal('100.00'),
            platform_fee_rate=Decimal('1.00'),
            platform_fee_amount=Decimal('1.00'),
            platform_fee_payer=Booking.PlatformFeePayer.CLIENT,
            platform_fee_source=Booking.PlatformFeeSource.GLOBAL,
            total_price=Decimal('101.00'),
        )
        BookingTimeSlot.objects.create(
            booking=booking,
            start_time=start,
            end_time=start + timedelta(hours=1),
            location_type=Booking.LocationType.OFFICE,
        )
        return booking

    def test_accrue_idempotent(self):
        booking = self._booking()
        a = accrue_platform_fee_for_booking(booking)
        b = accrue_platform_fee_for_booking(booking)
        self.assertIsNotNone(a)
        self.assertEqual(a.pk, b.pk)
        self.assertEqual(
            PlatformFeeEntry.objects.filter(
                booking=booking,
                status=PlatformFeeEntry.EntryStatus.ACCRUED,
            ).count(),
            1,
        )

    def test_reverse_pro_rata(self):
        booking = self._booking()
        accrue_platform_fee_for_booking(booking)
        reverse_platform_fee_for_booking(
            booking,
            refund_amount=Decimal('50.50'),
            net_before_refund=Decimal('101.00'),
        )
        reversed_row = PlatformFeeEntry.objects.get(
            booking=booking,
            status=PlatformFeeEntry.EntryStatus.REVERSED,
        )
        self.assertEqual(reversed_row.amount, Decimal('0.50'))


class StaffFeeApiTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.country, cls.cac, cls.currency = _seed()
        PlatformSettings.objects.update_or_create(
            pk=1,
            defaults={'platform_fee_rate': Decimal('1.00')},
        )
        cls.org_type = OrganizationTypeModel.objects.create(
            name='spa3',
            display_name='Spa',
        )
        cls.staff = User.objects.create_user(
            email='stafffee@example.com',
            username='stafffee',
            password='pass12345',
            is_staff=True,
        )
        cls.regular = User.objects.create_user(
            email='nofee@example.com',
            username='nofee',
            password='pass12345',
        )
        cls.org = Organization.objects.create(
            name='Staff Fee Org',
            type=cls.org_type,
            email='sfo@example.com',
            country=cls.country,
            default_currency=cls.cac,
        )
        OrganizationSettings.objects.get_or_create(organization=cls.org)
        cls.cat = ServiceCategory.objects.create(name='Therapy')

    def setUp(self):
        self.client = APIClient()

    def test_platform_settings_staff_only(self):
        self.client.force_authenticate(self.regular)
        res = self.client.get('/api/v1/staff/platform-settings/')
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        self.client.force_authenticate(self.staff)
        res = self.client.get('/api/v1/staff/platform-settings/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['platform_fee_rate'], '1.00')

        res = self.client.patch(
            '/api/v1/staff/platform-settings/',
            {'platform_fee_rate': '1.50'},
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['platform_fee_rate'], '1.50')

    def test_category_fee_crud(self):
        self.client.force_authenticate(self.staff)
        res = self.client.post(
            '/api/v1/staff/fees/categories/',
            {'category': str(self.cat.id), 'rate': '3.00'},
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        fee_id = res.data['id']
        res = self.client.patch(
            f'/api/v1/staff/fees/categories/{fee_id}/',
            {'rate': '3.25'},
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['rate'], '3.25')

    def test_org_fee_settings(self):
        self.client.force_authenticate(self.staff)
        url = f'/api/v1/staff/organizations/{self.org.id}/fee-settings/'
        res = self.client.patch(
            url,
            {
                'platform_fee_rate': '4.00',
                'platform_fee_payer': 'B',
            },
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['platform_fee_rate'], '4.00')
        self.assertEqual(res.data['platform_fee_payer']['value'], 'B')

        res = self.client.patch(
            url,
            {'clear_rate_override': True},
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertIsNone(res.data['platform_fee_rate'])

    def test_fee_summary(self):
        self.client.force_authenticate(self.staff)
        user = User.objects.create_user(
            email='b@example.com',
            username='buser',
            password='pass12345',
        )
        cat = ServiceCategory.objects.create(name='SumCat')
        sub = ServiceSubCategory.objects.create(name='SumSub', category=cat)
        service = Service.objects.create(
            name='SumSvc',
            sub_category=sub,
            organization=self.org,
            description='x',
            price_min=50,
            price_max=50,
            accepted_currency=self.cac,
        )
        booking = Booking.objects.create(
            user=user,
            service=service,
            organization=self.org,
            status=Booking.BookingStatus.COMPLETED,
            accepted_currency=self.cac,
            base_price=Decimal('50.00'),
            platform_fee_rate=Decimal('1.00'),
            platform_fee_amount=Decimal('0.50'),
            total_price=Decimal('50.50'),
        )
        PlatformFeeEntry.objects.create(
            booking=booking,
            organization=self.org,
            category=cat,
            currency=self.currency,
            amount=Decimal('0.50'),
            rate=Decimal('1.00'),
            payer=PlatformFeeEntry.FeePayer.CLIENT,
            source=PlatformFeeEntry.FeeSource.GLOBAL,
            status=PlatformFeeEntry.EntryStatus.ACCRUED,
        )
        res = self.client.get('/api/v1/staff/fees/summary/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res.data['by_currency']), 1)
        self.assertEqual(res.data['by_currency'][0]['net_fees'], '0.50')
