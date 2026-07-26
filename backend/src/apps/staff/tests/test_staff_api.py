"""Platform staff review and ledger APIs."""

from __future__ import annotations

from decimal import Decimal

from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from src.apps.finances.models import Currency
from src.apps.organizations.models import (
    Country,
    CountryAcceptedCurrency,
    Organization,
    OrganizationTypeModel,
)
from src.apps.payments.models import PaymentProvider, PaymentTransaction
from src.apps.services.models import ServiceCategory
from src.apps.users.models import User
from src.apps.test_helpers.geo import seed_cities_country, seed_us_country_and_currency, create_org_address

UserModel = get_user_model()


class StaffApiTests(TestCase):
    @classmethod
    def setUpTestData(cls):
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
        ctry, cac = seed_us_country_and_currency()
        cls.currency = cur
        cls.org_type = OrganizationTypeModel.objects.create(
            name='spa',
            display_name='Spa',
        )
        cls.staff = UserModel.objects.create_user(
            email='staff@example.com',
            username='staff',
            password='pass12345',
            is_staff=True,
        )
        cls.regular = UserModel.objects.create_user(
            email='user@example.com',
            username='user',
            password='pass12345',
        )
        cls.pending_user = UserModel.objects.create_user(
            email='kyc@example.com',
            username='kyc',
            password='pass12345',
            verification_status=User.VerificationStatus.PENDING,
        )
        cls.org = Organization.objects.create(
            name='KYB Org',
            type=cls.org_type,
            email='kyb@example.com',
            country=ctry,
            default_currency=cac,
            verification_status=Organization.VerificationStatus.PENDING,
        )
        cls.category = ServiceCategory.objects.create(name='Massage', icon='spa')
        cls.provider = PaymentProvider.objects.create(
            code='mainmoney',
            provider_type=PaymentProvider.ProviderType.OTHER,
            display_name='MainMoney',
            is_active=True,
        )

    def setUp(self):
        self.api = APIClient()

    def test_non_staff_forbidden(self):
        self.api.force_authenticate(user=self.regular)
        res = self.api.get('/api/v1/staff/users/')
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    def test_profile_exposes_is_staff(self):
        self.api.force_authenticate(user=self.staff)
        res = self.api.get('/api/v1/auth/profile/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(res.data['is_staff'])
        self.api.force_authenticate(user=self.regular)
        res = self.api.get('/api/v1/auth/profile/')
        self.assertFalse(res.data['is_staff'])

    def test_kyc_approve_and_reject(self):
        self.api.force_authenticate(user=self.staff)
        list_res = self.api.get(
            '/api/v1/staff/users/',
            {'verification_status': User.VerificationStatus.PENDING},
        )
        self.assertEqual(list_res.status_code, status.HTTP_200_OK)
        ids = [row['id'] for row in list_res.data['results']]
        self.assertIn(str(self.pending_user.id), ids)

        reject = self.api.post(
            f'/api/v1/staff/users/{self.pending_user.id}/reject/',
            {'reason': 'Blurry ID'},
            format='json',
        )
        self.assertEqual(reject.status_code, status.HTTP_200_OK)
        self.pending_user.refresh_from_db()
        self.assertEqual(
            self.pending_user.verification_status,
            User.VerificationStatus.REJECTED,
        )
        self.assertEqual(self.pending_user.rejection_reason, 'Blurry ID')

        approve = self.api.post(
            f'/api/v1/staff/users/{self.pending_user.id}/approve/',
        )
        self.assertEqual(approve.status_code, status.HTTP_200_OK)
        self.pending_user.refresh_from_db()
        self.assertEqual(
            self.pending_user.verification_status,
            User.VerificationStatus.VERIFIED,
        )

        blocked = self.api.post(
            f'/api/v1/staff/users/{self.pending_user.id}/reject/',
            {'reason': 'Too late'},
            format='json',
        )
        self.assertEqual(blocked.status_code, status.HTTP_400_BAD_REQUEST)

    def test_kyb_approve_suspend_unsuspend(self):
        self.api.force_authenticate(user=self.staff)
        res = self.api.post(f'/api/v1/staff/organizations/{self.org.id}/approve/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.org.refresh_from_db()
        self.assertEqual(
            self.org.verification_status,
            Organization.VerificationStatus.VERIFIED,
        )

        cannot_reject = self.api.post(
            f'/api/v1/staff/organizations/{self.org.id}/reject/',
            {'reason': 'No'},
            format='json',
        )
        self.assertEqual(cannot_reject.status_code, status.HTTP_400_BAD_REQUEST)

        suspend = self.api.post(
            f'/api/v1/staff/organizations/{self.org.id}/suspend/',
        )
        self.assertEqual(suspend.status_code, status.HTTP_200_OK)
        self.org.refresh_from_db()
        self.assertEqual(
            self.org.verification_status,
            Organization.VerificationStatus.SUSPENDED,
        )
        self.assertEqual(suspend.data['verification_status']['css'], 'secondary')

        unsuspend = self.api.post(
            f'/api/v1/staff/organizations/{self.org.id}/unsuspend/',
        )
        self.assertEqual(unsuspend.status_code, status.HTTP_200_OK)
        self.org.refresh_from_db()
        self.assertEqual(
            self.org.verification_status,
            Organization.VerificationStatus.VERIFIED,
        )

    def test_users_search(self):
        self.api.force_authenticate(user=self.staff)
        res = self.api.get('/api/v1/staff/users/', {'search': 'kyc@'})
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        emails = [row['email'] for row in res.data['results']]
        self.assertIn('kyc@example.com', emails)

    def test_overview(self):
        self.api.force_authenticate(user=self.staff)
        res = self.api.get('/api/v1/staff/overview/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertIn('queues', res.data)
        self.assertGreaterEqual(res.data['queues']['pending_kyc'], 1)
        self.assertGreaterEqual(res.data['queues']['pending_kyb'], 1)
        self.assertEqual(len(res.data['bookings_last_14_days']), 14)
        self.assertEqual(len(res.data['payments_last_14_days']), 14)
        self.assertIn('fees_by_currency', res.data)

    def test_taxonomy_create_category(self):
        self.api.force_authenticate(user=self.staff)
        res = self.api.post(
            '/api/v1/staff/taxonomy/categories/',
            {
                'name': 'Therapy',
                'description': 'Talk therapy',
                'icon': 'heart',
                'is_active': True,
                'sort_order': 2,
            },
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res.data['name'], 'Therapy')

    def test_taxonomy_feature_type_create_and_patch(self):
        from src.apps.services.models import ServiceFeature

        self.api.force_authenticate(user=self.staff)
        create = self.api.post(
            '/api/v1/staff/taxonomy/features/',
            {
                'name': 'Towels',
                'feature_type': 'R',
                'description': 'Bring towels',
                'icon': 'towel',
            },
            format='json',
        )
        self.assertEqual(create.status_code, status.HTTP_201_CREATED, create.data)
        self.assertEqual(create.data['feature_type']['value'], 'R')
        self.assertEqual(create.data['feature_type']['css'], 'warning')
        feature_id = create.data['id']
        row = ServiceFeature.objects.get(pk=feature_id)
        self.assertEqual(row.feature_type, ServiceFeature.ServiceFeatureType.REQUIREMENT)

        patch = self.api.patch(
            f'/api/v1/staff/taxonomy/features/{feature_id}/',
            {'feature_type': {'value': 'S', 'title': 'Safety', 'css': 'success'}},
            format='json',
        )
        self.assertEqual(patch.status_code, status.HTTP_200_OK, patch.data)
        self.assertEqual(patch.data['feature_type']['value'], 'S')
        self.assertEqual(patch.data['feature_type']['css'], 'success')
        row.refresh_from_db()
        self.assertEqual(row.feature_type, ServiceFeature.ServiceFeatureType.SAFETY)

    def test_payments_ledger_list(self):
        from src.apps.bookings.models import Booking
        from src.apps.services.models import Service, ServiceSubCategory

        sub = ServiceSubCategory.objects.create(
            name='Swedish',
            category=self.category,
        )
        service = Service.objects.create(
            cities_city=seed_cities_country(city_name='NYC')[1],
            
            name='Swedish',
            sub_category=sub,
            organization=self.org,
            description='x',
            price_min=50,
            price_max=100,
            accepted_currency=self.org.default_currency,
            address='1 Main',
            postal_code='10001',
            country_text='US',
            country=self.org.country,
        )
        booking = Booking.objects.create(
            user=self.regular,
            service=service,
            organization=self.org,
            status=Booking.BookingStatus.REQUESTED,
            total_price=Decimal('75.00'),
            accepted_currency=self.org.default_currency,
        )
        PaymentTransaction.objects.create(
            booking=booking,
            payment_provider=self.provider,
            user=self.regular,
            amount=Decimal('75.00'),
            currency=self.currency,
            kind=PaymentTransaction.TransactionKind.PAYMENT,
            status=PaymentTransaction.TransactionStatus.PROCESSING,
            client_reference='bk_test_1',
        )
        self.api.force_authenticate(user=self.staff)
        res = self.api.get('/api/v1/staff/payments/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertGreaterEqual(res.data['count'], 1)
        row = res.data['results'][0]
        self.assertEqual(row['provider_code'], 'mainmoney')
        self.assertEqual(row['status']['css'], 'info')
        self.assertEqual(row['kind']['css'], 'primary')
        self.assertEqual(booking.get_status_css(), 'warning')
