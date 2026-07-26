from datetime import timedelta
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APIClient

from src.apps.bookings.models import Booking
from src.apps.finances.models import Currency
from src.apps.test_helpers.geo import seed_cities_country,  create_org_address, seed_us_country_and_currency
from src.apps.organizations.models import (
    Country,
    CountryAcceptedCurrency,
    Organization,
    OrganizationMembership,
    OrganizationTeamInvite,
    OrganizationTypeModel,
)
from src.apps.services.models import Service, ServiceCategory, ServiceSubCategory

User = get_user_model()


class OrganizationTeamAndAnalyticsTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.country, cls.accepted_currency = seed_us_country_and_currency()
        cls.currency = cls.accepted_currency.currency
        cls.org_type = OrganizationTypeModel.objects.create(
            name="spa",
            display_name="Spa",
        )
        cls.org = Organization.objects.create(
            name="Spa",
            type=cls.org_type,
            email="spa@example.com",
            country=cls.country,
            default_currency=cls.accepted_currency,
        )
        cls.owner = User.objects.create_user(
            email="owner@example.com",
            username="owner",
            password="secret123",
        )
        cls.member = User.objects.create_user(
            email="member@example.com",
            username="member",
            password="secret123",
        )
        cls.customer = User.objects.create_user(
            email="customer@example.com",
            username="customer",
            password="secret123",
        )
        cls.owner_membership = OrganizationMembership.objects.create(
            user=cls.owner,
            organization=cls.org,
            role=OrganizationMembership.OrganizationMemberRole.OWNER,
        )
        cls.category = ServiceCategory.objects.create(name="Massage")
        cls.subcategory = ServiceSubCategory.objects.create(
            name="Swedish",
            category=cls.category,
        )
        cls.service = Service.objects.create(
            cities_city=seed_cities_country(city_name='New York')[1],
            
            name="Massage",
            sub_category=cls.subcategory,
            organization=cls.org,
            description="Relaxing",
            price_min=50,
            price_max=50,
            accepted_currency=cls.accepted_currency,
            address="1 Main",
            postal_code="10001",
            country_text="US",
            country=cls.country,
        )

    def setUp(self):
        self.client = APIClient()
        self.client.force_authenticate(self.owner)

    def test_invite_registers_existing_user_and_creates_pending_invite(self):
        member_response = self.client.post(
            f"/api/v1/organizations/{self.org.id}/team/invite/",
            {
                "email": self.member.email,
                "role": {"value": "T", "title": "", "css": "secondary"},
            },
            format="json",
        )
        self.assertEqual(member_response.status_code, status.HTTP_201_CREATED)
        membership = OrganizationMembership.objects.get(organization=self.org, user=self.member)
        self.assertEqual(membership.role, "T")

        invite_response = self.client.post(
            f"/api/v1/organizations/{self.org.id}/team/invite/",
            {
                "email": "new-user@example.com",
                "role": {"value": "A", "title": "", "css": "danger"},
            },
            format="json",
        )
        self.assertEqual(invite_response.status_code, status.HTTP_201_CREATED)
        invite = OrganizationTeamInvite.objects.get(organization=self.org, email="new-user@example.com")
        self.assertEqual(invite.role, "A")
        self.assertIsNotNone(invite.token)

    def test_admin_can_update_membership_but_cannot_remove_sole_owner(self):
        membership = OrganizationMembership.objects.create(
            organization=self.org,
            user=self.member,
            role=OrganizationMembership.OrganizationMemberRole.STAFF,
        )
        response = self.client.patch(
            f"/api/v1/organizations/{self.org.id}/team/{membership.id}/",
            {"role": {"value": "M", "title": "", "css": "info"}},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        membership.refresh_from_db()
        self.assertEqual(membership.role, "M")

        remove_owner = self.client.delete(f"/api/v1/organizations/{self.org.id}/team/{self.owner_membership.id}/")
        self.assertEqual(remove_owner.status_code, status.HTTP_400_BAD_REQUEST)

    def test_analytics_returns_live_booking_counts(self):
        for booking_status in (
            Booking.BookingStatus.CONFIRMED,
            Booking.BookingStatus.COMPLETED,
            Booking.BookingStatus.CANCELLED,
        ):
            Booking.objects.create(
                user=self.customer,
                service=self.service,
                organization=self.org,
                status=booking_status,
                total_price=Decimal("50.00"),
                accepted_currency=self.accepted_currency,
            )
        response = self.client.get(
            f"/api/v1/organizations/{self.org.id}/analytics/",
            {
                "date_from": (timezone.localdate() - timedelta(days=1)).isoformat(),
                "date_to": (timezone.localdate() + timedelta(days=1)).isoformat(),
            },
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["total_bookings"], 3)
        self.assertEqual(response.data["confirmed_bookings"], 1)
        self.assertEqual(response.data["completed_bookings"], 1)
        self.assertEqual(response.data["cancelled_bookings"], 1)
        self.assertEqual(response.data["revenue"], "0.00")
        self.assertEqual(response.data["currency"], "USD")
