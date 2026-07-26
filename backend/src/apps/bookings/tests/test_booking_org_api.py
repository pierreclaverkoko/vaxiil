"""Organization booking list filter, cancel+refund, reschedule."""

from datetime import timedelta
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APIClient, APIRequestFactory

from src.apps.bookings.cancellation_models import CancellationPolicy
from src.apps.bookings.models import Booking, BookingTimeSlot
from src.apps.bookings.serializers import BookingCreateSerializer, BookingSerializer
from src.apps.finances.models import Currency
from src.apps.organizations.models import (
    Organization,
    OrganizationMembership,
    OrganizationTypeModel,
)
from src.apps.payments.models import PaymentProvider, PaymentTransaction
from src.apps.services.models import Service, ServiceCategory, ServiceSubCategory
from src.apps.test_helpers.geo import seed_cities_country, seed_us_country_and_currency, create_org_address

User = get_user_model()


def _seed_us():
    return seed_us_country_and_currency()




class BookingOrgFilterAndActionsTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.country, cls.cac = _seed_us()
        cls.org_type = OrganizationTypeModel.objects.create(
            name="spa",
            display_name="Spa",
        )
        cls.customer = User.objects.create_user(
            email="cust@example.com",
            username="cust",
            password="pass12345",
            verification_status=User.VerificationStatus.VERIFIED,
        )
        cls.owner = User.objects.create_user(
            email="owner@example.com",
            username="owner",
            password="pass12345",
        )
        cls.org = Organization.objects.create(
            name="Org A",
            type=cls.org_type,
            email="a@example.com",
            country=cls.country,
            default_currency=cls.cac,
        )
        OrganizationMembership.objects.create(
            user=cls.owner,
            organization=cls.org,
            role=OrganizationMembership.OrganizationMemberRole.OWNER,
        )
        cls.category = ServiceCategory.objects.create(name="Massage")
        cls.sub = ServiceSubCategory.objects.create(
            name="Swedish",
            category=cls.category,
        )
        cls.service = Service.objects.create(
            cities_city=seed_cities_country(city_name='NYC')[1],
            
            name="Swedish",
            sub_category=cls.sub,
            organization=cls.org,
            description="x",
            price_min=50,
            price_max=100,
            accepted_currency=cls.cac,
            address="1 Main",
            postal_code="10001",
            country_text="US",
            country=cls.country,
        )
        start = timezone.now() + timedelta(days=7)
        cls.booking = Booking.objects.create(
            user=cls.customer,
            service=cls.service,
            organization=cls.org,
            status=Booking.BookingStatus.CONFIRMED,
            total_price=Decimal("75.00"),
            accepted_currency=cls.cac,
        )
        BookingTimeSlot.objects.create(
            booking=cls.booking,
            start_time=start,
            end_time=start + timedelta(hours=1),
            location_type=Booking.LocationType.OFFICE,
        )
        cls.provider = PaymentProvider.objects.create(
            code="stub-test",
            provider_type=PaymentProvider.ProviderType.OTHER,
            display_name="Stub",
            is_active=True,
        )
        cls.provider.supported_countries.add(cls.country)
        cls.provider.supported_currencies.add(cls.cac.currency)
        cls._attach_payment(cls.booking)
        CancellationPolicy.objects.create(
            organization=cls.org,
            name="Default",
            policy_type=CancellationPolicy.PolicyType.FLEXIBLE,
            description="test",
            full_refund_hours=48,
            cancellation_windows={},
        )

    @staticmethod
    def _attach_payment(booking):
        PaymentTransaction.objects.create(
            booking=booking,
            payment_provider=BookingOrgFilterAndActionsTests.provider,
            user=BookingOrgFilterAndActionsTests.customer,
            amount=Decimal("75.00"),
            currency=BookingOrgFilterAndActionsTests.cac.currency,
            kind=PaymentTransaction.TransactionKind.PAYMENT,
            status=PaymentTransaction.TransactionStatus.SUCCEEDED,
            provider_reference=f"pay_{booking.pk}",
        )

    @classmethod
    def _make_booking(cls, suffix=""):
        start = timezone.now() + timedelta(days=7)
        b = Booking.objects.create(
            user=cls.customer,
            service=cls.service,
            organization=cls.org,
            status=Booking.BookingStatus.CONFIRMED,
            total_price=Decimal("75.00"),
            accepted_currency=cls.cac,
        )
        BookingTimeSlot.objects.create(
            booking=b,
            start_time=start,
            end_time=start + timedelta(hours=1),
            location_type=Booking.LocationType.OFFICE,
        )
        cls._attach_payment(b)
        return b

    def setUp(self):
        self.api = APIClient()

    def test_list_filter_by_organization(self):
        self.api.force_authenticate(user=self.owner)
        res = self.api.get(
            "/api/v1/bookings/",
            {"organization": str(self.org.id)},
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        data = res.data
        results = data.get("results", data) if isinstance(data, dict) else data
        ids = [str(r["id"]) for r in results]
        self.assertIn(str(self.booking.id), ids)

    def test_org_staff_sees_only_shared_client_identity(self):
        self.customer.first_name = "Private"
        self.customer.last_name = "Client"
        self.customer.phone = "+15555550123"
        self.customer.date_of_birth = timezone.localdate() - timedelta(days=365 * 30)
        self.customer.sex = User.Sex.FEMALE
        self.customer.show_real_name = False
        self.customer.show_phone_number = False
        self.customer.show_email = False
        self.customer.save()
        self.customer.generate_trust_alias()

        request = APIRequestFactory().get("/api/v1/bookings/")
        request.user = self.owner
        client = BookingSerializer(
            self.booking,
            context={"request": request},
        ).data["client"]

        self.assertEqual(client["id"], str(self.customer.id))
        self.assertEqual(client["trust_alias"], self.customer.trust_alias)
        # Demographics remain visible to org staff when name/contact are private.
        self.assertIsNotNone(client["age"])
        self.assertEqual(client["sex"]["value"], User.Sex.FEMALE)
        self.assertIsNone(client["first_name"])
        self.assertIsNone(client["last_name"])
        self.assertIsNone(client["phone"])
        self.assertIsNone(client["email"])

        self.booking.share_name = True
        self.booking.share_phone = True
        self.booking.share_email = True
        self.booking.save()
        client = BookingSerializer(
            self.booking,
            context={"request": request},
        ).data["client"]

        self.assertIsNotNone(client["age"])
        self.assertEqual(client["sex"]["value"], User.Sex.FEMALE)
        self.assertEqual(client["first_name"], "Private")
        self.assertEqual(client["last_name"], "Client")
        self.assertEqual(client["phone"], "+15555550123")
        self.assertEqual(client["email"], self.customer.email)

    def test_org_staff_ignores_profile_show_flags_without_booking_share(self):
        self.customer.first_name = "Visible"
        self.customer.last_name = "Profile"
        self.customer.phone = "+15555550999"
        self.customer.show_real_name = True
        self.customer.show_phone_number = True
        self.customer.show_email = True
        self.customer.save()
        self.booking.share_name = False
        self.booking.share_phone = False
        self.booking.share_email = False
        self.booking.save()

        request = APIRequestFactory().get("/api/v1/bookings/")
        request.user = self.owner
        client = BookingSerializer(
            self.booking,
            context={"request": request},
        ).data["client"]

        self.assertIsNone(client["first_name"])
        self.assertIsNone(client["last_name"])
        self.assertIsNone(client["phone"])
        self.assertIsNone(client["email"])

    def test_booking_create_persists_location_type(self):
        request = APIRequestFactory().post("/api/v1/bookings/")
        request.user = self.customer
        start = timezone.now() + timedelta(days=14)
        serializer = BookingCreateSerializer(
            data={
                "service": str(self.service.id),
                "total_price": "75.00",
                "share_name": True,
                "time_slots": [
                    {
                        "start_time": start.isoformat(),
                        "end_time": (start + timedelta(hours=1)).isoformat(),
                        "location_type": "H",
                    }
                ],
            },
            context={"request": request},
        )
        self.assertTrue(serializer.is_valid(), serializer.errors)
        booking = serializer.save()
        slot = booking.time_slots.get()
        self.assertEqual(slot.location_type, Booking.LocationType.HOME)

        out = BookingSerializer(booking, context={"request": request}).data
        self.assertEqual(out["time_slots"][0]["location_type"]["value"], "H")
        self.assertIn("share_name", out)

    def test_booking_create_requires_verified_kyc(self):
        unverified = User.objects.create_user(
            email="unverified@example.com",
            username="unverified",
            password="pass12345",
            verification_status=User.VerificationStatus.PENDING,
        )
        request = APIRequestFactory().post("/api/v1/bookings/")
        request.user = unverified
        start = timezone.now() + timedelta(days=7)
        serializer = BookingCreateSerializer(
            data={
                "service": str(self.service.id),
                "total_price": "75.00",
                "share_name": True,
                "time_slots": [
                    {
                        "start_time": start.isoformat(),
                        "end_time": (start + timedelta(hours=1)).isoformat(),
                        "location_type": {
                            "value": Booking.LocationType.OFFICE,
                            "title": "",
                            "css": "default",
                        },
                    }
                ],
            },
            context={"request": request},
        )
        self.assertFalse(serializer.is_valid())
        self.assertTrue(serializer.errors)

    def test_booking_create_requires_name_sharing_when_org_requires_it(self):
        request = APIRequestFactory().post("/api/v1/bookings/")
        request.user = self.customer
        start = timezone.now() + timedelta(days=7)
        serializer = BookingCreateSerializer(
            data={
                "service": str(self.service.id),
                "total_price": "75.00",
                "time_slots": [
                    {
                        "start_time": start.isoformat(),
                        "end_time": (start + timedelta(hours=1)).isoformat(),
                        "location_type": {
                            "value": Booking.LocationType.OFFICE,
                            "title": "",
                            "css": "default",
                        },
                    }
                ],
            },
            context={"request": request},
        )

        self.assertFalse(serializer.is_valid())
        self.assertIn("share_name", serializer.errors)

    def test_cancel_returns_refund_and_booking(self):
        b = self._make_booking("cancel")
        self.api.force_authenticate(user=self.owner)
        res = self.api.post(
            f"/api/v1/bookings/{b.id}/cancel/",
            {"reason": "test"},
            format="json",
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertIn("booking", res.data)
        self.assertIn("refund", res.data)
        self.assertEqual(res.data["booking"]["status"]["value"], "X")
        refund = res.data["refund"]
        self.assertTrue(refund["attempted"])
        self.assertIsNotNone(refund.get("amount"))
        self.assertEqual(refund.get("destination"), "wallet")
        from src.apps.payments.models import RefundWallet

        wallet = RefundWallet.objects.get(user=self.customer, currency=self.cac.currency)
        self.assertEqual(wallet.balance, Decimal(refund["amount"]))

    def test_reschedule_creates_proposal_until_accepted(self):
        b = self._make_booking("resched")
        self.api.force_authenticate(user=self.owner)
        new_start = timezone.now() + timedelta(days=14)
        res = self.api.post(
            f"/api/v1/bookings/{b.id}/reschedule/",
            {
                "time_slots": [
                    {
                        "start_time": new_start.isoformat(),
                        "end_time": (new_start + timedelta(hours=1)).isoformat(),
                        "location_type": {"value": "O", "title": "", "css": "default"},
                    }
                ]
            },
            format="json",
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data["status"]["value"], "R")
        self.assertIsNotNone(res.data.get("pending_reschedule"))
        # Active slots unchanged until client accepts.
        self.assertEqual(b.time_slots.filter(deleted_at__isnull=True).count(), 1)

        self.api.force_authenticate(user=self.customer)
        accepted = self.api.post(f"/api/v1/bookings/{b.id}/reschedule/accept/", format="json")
        self.assertEqual(accepted.status_code, status.HTTP_200_OK, accepted.data)
        self.assertEqual(accepted.data["status"]["value"], "F")
        self.assertIsNone(accepted.data.get("pending_reschedule"))
        b.refresh_from_db()
        slot = b.time_slots.filter(deleted_at__isnull=True).get()
        self.assertEqual(slot.start_time.replace(microsecond=0), new_start.replace(microsecond=0))

    def test_organization_staff_can_confirm_reject_and_complete(self):
        requested = Booking.objects.create(
            user=self.customer,
            service=self.service,
            organization=self.org,
            status=Booking.BookingStatus.REQUESTED,
            total_price=Decimal("75.00"),
            accepted_currency=self.cac,
        )
        self._attach_payment(requested)
        self.api.force_authenticate(user=self.owner)
        unpaid = Booking.objects.create(
            user=self.customer,
            service=self.service,
            organization=self.org,
            status=Booking.BookingStatus.REQUESTED,
            total_price=Decimal("75.00"),
            accepted_currency=self.cac,
        )
        blocked = self.api.post(f"/api/v1/bookings/{unpaid.id}/confirm/", format="json")
        self.assertEqual(blocked.status_code, status.HTTP_400_BAD_REQUEST)

        confirmed = self.api.post(f"/api/v1/bookings/{requested.id}/confirm/", format="json")
        self.assertEqual(confirmed.status_code, status.HTTP_200_OK)
        self.assertEqual(confirmed.data["status"]["value"], "F")
        self.assertTrue(confirmed.data["is_paid"])

        completed = self.api.post(f"/api/v1/bookings/{requested.id}/complete/", format="json")
        self.assertEqual(completed.status_code, status.HTTP_200_OK)
        self.assertEqual(completed.data["status"]["value"], "M")

        rejected = Booking.objects.create(
            user=self.customer,
            service=self.service,
            organization=self.org,
            status=Booking.BookingStatus.REQUESTED,
            total_price=Decimal("75.00"),
            accepted_currency=self.cac,
        )
        response = self.api.post(
            f"/api/v1/bookings/{rejected.id}/reject/",
            {"reason": "No availability"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["status"]["value"], "X")
        self.assertEqual(response.data["cancellation_reason"], "No availability")

        missing_reason = Booking.objects.create(
            user=self.customer,
            service=self.service,
            organization=self.org,
            status=Booking.BookingStatus.REQUESTED,
            total_price=Decimal("75.00"),
            accepted_currency=self.cac,
        )
        blank = self.api.post(
            f"/api/v1/bookings/{missing_reason.id}/reject/",
            {"reason": ""},
            format="json",
        )
        self.assertEqual(blank.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("reason", blank.data)

    def test_customer_cannot_confirm_booking(self):
        booking = Booking.objects.create(
            user=self.customer,
            service=self.service,
            organization=self.org,
            status=Booking.BookingStatus.REQUESTED,
            total_price=Decimal("75.00"),
            accepted_currency=self.cac,
        )
        self.api.force_authenticate(user=self.customer)
        response = self.api.post(f"/api/v1/bookings/{booking.id}/confirm/", format="json")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_booking_create_rejects_overlapping_active_booking(self):
        request = APIRequestFactory().post("/api/v1/bookings/")
        request.user = self.customer
        existing_slot = self.booking.time_slots.get()
        serializer = BookingCreateSerializer(
            data={
                "service": str(self.service.id),
                "total_price": "75.00",
                "share_name": True,
                "time_slots": [
                    {
                        "start_time": existing_slot.start_time.isoformat(),
                        "end_time": existing_slot.end_time.isoformat(),
                        "location_type": {"value": "O", "title": "", "css": "default"},
                    }
                ],
            },
            context={"request": request},
        )
        self.assertFalse(serializer.is_valid())
        self.assertIn("time_slots", serializer.errors)
        err = " ".join(str(x) for x in serializer.errors["time_slots"])
        self.assertIn(str(self.booking.pk)[:8], err)
        self.assertIn("conflicts", serializer.errors)

    def test_unpaid_reschedule_accept_requires_payment(self):
        start = timezone.now() + timedelta(days=10)
        unpaid = Booking.objects.create(
            user=self.customer,
            service=self.service,
            organization=self.org,
            status=Booking.BookingStatus.REQUESTED,
            total_price=Decimal("75.00"),
            accepted_currency=self.cac,
        )
        BookingTimeSlot.objects.create(
            booking=unpaid,
            start_time=start,
            end_time=start + timedelta(hours=1),
            location_type=Booking.LocationType.OFFICE,
        )
        self.api.force_authenticate(user=self.owner)
        new_start = timezone.now() + timedelta(days=15)
        proposed = self.api.post(
            f"/api/v1/bookings/{unpaid.id}/reschedule/",
            {
                "time_slots": [
                    {
                        "start_time": new_start.isoformat(),
                        "end_time": (new_start + timedelta(hours=1)).isoformat(),
                        "location_type": {"value": "O", "title": "", "css": "default"},
                    }
                ]
            },
            format="json",
        )
        self.assertEqual(proposed.status_code, status.HTTP_200_OK, proposed.data)
        self.api.force_authenticate(user=self.customer)
        blocked = self.api.post(
            f"/api/v1/bookings/{unpaid.id}/reschedule/accept/",
            format="json",
        )
        self.assertEqual(blocked.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("Payment", str(blocked.data))

        self._attach_payment(unpaid)
        accepted = self.api.post(
            f"/api/v1/bookings/{unpaid.id}/reschedule/accept/",
            format="json",
        )
        self.assertEqual(accepted.status_code, status.HTTP_200_OK, accepted.data)
        self.assertEqual(accepted.data["status"]["value"], "F")

    def test_unpaid_reschedule_allows_payment_link(self):
        from unittest.mock import patch

        from src.apps.payments.adapters.base import PaymentLinkResult

        start = timezone.now() + timedelta(days=10)
        unpaid = Booking.objects.create(
            user=self.customer,
            service=self.service,
            organization=self.org,
            status=Booking.BookingStatus.REQUESTED,
            total_price=Decimal("75.00"),
            accepted_currency=self.cac,
        )
        BookingTimeSlot.objects.create(
            booking=unpaid,
            start_time=start,
            end_time=start + timedelta(hours=1),
            location_type=Booking.LocationType.OFFICE,
        )
        PaymentProvider.objects.get_or_create(
            code="mainmoney",
            defaults={
                "provider_type": PaymentProvider.ProviderType.OTHER,
                "display_name": "MainMoney",
                "is_active": True,
                "config": {"api_key": "test", "base_url": "https://pay.example.test"},
            },
        )
        self.api.force_authenticate(user=self.owner)
        new_start = timezone.now() + timedelta(days=15)
        proposed = self.api.post(
            f"/api/v1/bookings/{unpaid.id}/reschedule/",
            {
                "time_slots": [
                    {
                        "start_time": new_start.isoformat(),
                        "end_time": (new_start + timedelta(hours=1)).isoformat(),
                        "location_type": {"value": "O", "title": "", "css": "default"},
                    }
                ]
            },
            format="json",
        )
        self.assertEqual(proposed.status_code, status.HTTP_200_OK, proposed.data)
        self.assertEqual(proposed.data["status"]["value"], "R")
        self.assertFalse(proposed.data["is_paid"])

        self.api.force_authenticate(user=self.customer)
        with patch(
            "src.apps.payments.adapters.mainmoney.MainmoneyPaymentAdapter.create_payment_link",
            return_value=PaymentLinkResult(
                url="https://pay.mainmoney.net/l/stub",
                link_id="pl_stub",
                slug="stub",
                merchant_reference="ignored",
                response_body={},
            ),
        ):
            pay = self.api.post(
                f"/api/v1/payments/bookings/{unpaid.id}/payment-link/",
            )
        self.assertEqual(pay.status_code, status.HTTP_201_CREATED, pay.data)
