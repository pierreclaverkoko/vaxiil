"""GET /organizations/mine-summary/ and membership role on org list."""

from decimal import Decimal

from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from src.apps.bookings.models import Booking
from src.apps.organizations.models import (
    Organization,
    OrganizationMembership,
    OrganizationTypeModel,
)
from src.apps.services.models import Service, ServiceCategory, ServiceSubCategory
from src.apps.test_helpers.geo import create_org_address, seed_us_country_and_currency

User = get_user_model()


class OrganizationMineSummaryAPITests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.country, cls.cac = seed_us_country_and_currency()
        cls.org_type = OrganizationTypeModel.objects.create(
            name='spa',
            display_name='Spa',
        )
        cls.owner = User.objects.create_user(
            email='owner@example.com',
            username='owner',
            password='secret123',
            role=User.UserRole.CLIENT,
        )
        cls.org = Organization.objects.create(
            name='Verdant Harvest Co.',
            type=cls.org_type,
            email='verdant@example.com',
            country=cls.country,
            default_currency=cls.cac,
        )
        create_org_address(cls.org, cls.country, city='Brooklyn')
        OrganizationMembership.objects.create(
            user=cls.owner,
            organization=cls.org,
            role=OrganizationMembership.OrganizationMemberRole.OWNER,
        )
        cls.category = ServiceCategory.objects.create(name='Wellness')
        cls.subcategory = ServiceSubCategory.objects.create(
            name='Session',
            category=cls.category,
        )
        cls.service = Service.objects.create(
            name='Forest Bath',
            sub_category=cls.subcategory,
            organization=cls.org,
            description='Calm',
            price_min=40,
            price_max=80,
            accepted_currency=cls.cac,
            address='1 Grove',
            city='Brooklyn',
            postal_code='11201',
            country_text='US',
            country=cls.country,
        )

    def setUp(self):
        self.client = APIClient()
        self.client.force_authenticate(user=self.owner)

    def test_mine_summary_counts_completed_bookings(self):
        Booking.objects.create(
            user=self.owner,
            service=self.service,
            organization=self.org,
            status=Booking.BookingStatus.COMPLETED,
            total_price=Decimal('50.00'),
            accepted_currency=self.cac,
        )
        Booking.objects.create(
            user=self.owner,
            service=self.service,
            organization=self.org,
            status=Booking.BookingStatus.CANCELLED,
            total_price=Decimal('50.00'),
            accepted_currency=self.cac,
        )
        res = self.client.get('/api/v1/organizations/mine-summary/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['organization_count'], 1)
        self.assertEqual(res.data['collective_beneficiaries'], 1)

    def test_list_includes_my_membership_role(self):
        res = self.client.get('/api/v1/organizations/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        row = next(x for x in res.data if x['id'] == str(self.org.id))
        self.assertEqual(row['my_membership_role']['value'], 'O')
        self.assertEqual(row['my_membership_role']['title'], 'Owner')
