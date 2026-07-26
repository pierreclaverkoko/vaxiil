"""Open-slots API and AvailabilityService.list_open_slots."""

from datetime import datetime, time, timedelta
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APIClient

from src.apps.bookings.models import (
    AvailabilityException,
    Booking,
    BookingTimeSlot,
    BusinessHours,
)
from src.apps.bookings.services import AvailabilityService
from src.apps.finances.models import Currency
from src.apps.organizations.models import (
    Country,
    CountryAcceptedCurrency,
    Organization,
    OrganizationSettings,
    OrganizationTypeModel,
)
from src.apps.services.models import Service, ServiceCategory, ServiceSubCategory, ServiceVariantModel
from src.apps.test_helpers.geo import seed_cities_country, seed_us_country_and_currency, create_org_address

User = get_user_model()


def _seed():
    return seed_us_country_and_currency()


class OpenSlotsTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.country, cls.cac = _seed()
        cls.org_type = OrganizationTypeModel.objects.create(name='spa', display_name='Spa')
        cls.org = Organization.objects.create(
            name='Hours Org',
            type=cls.org_type,
            email='hours@example.com',
            country=cls.country,
            default_currency=cls.cac,
            verification_status=Organization.VerificationStatus.VERIFIED,
        )
        OrganizationSettings.objects.create(
            organization=cls.org,
            minimum_booking_hours_notice=0,
            maximum_booking_days_ahead=90,
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
            is_active=True,
        )
        ServiceVariantModel.objects.create(
            service=cls.service,
            name='60 min',
            duration_minutes=60,
            price=Decimal('75.00'),
        )
        # Next Monday
        today = timezone.localdate()
        cls.monday = today + timedelta(days=(7 - today.weekday()) % 7 or 7)
        BusinessHours.objects.create(
            organization=cls.org,
            day_of_week=BusinessHours.Weekday.MONDAY,
            open_time=time(9, 0),
            close_time=time(12, 0),
            is_closed=False,
        )
        BusinessHours.objects.create(
            organization=cls.org,
            day_of_week=BusinessHours.Weekday.TUESDAY,
            open_time=time(9, 0),
            close_time=time(17, 0),
            is_closed=True,
        )
        cls.customer = User.objects.create_user(
            email='slots@example.com',
            username='slots',
            password='pass12345',
        )

    def test_list_open_slots_respects_hours(self):
        slots = AvailabilityService.list_open_slots(
            service=self.service,
            day=self.monday,
            duration_minutes=60,
        )
        self.assertEqual(len(slots), 3)  # 09, 10, 11
        self.assertEqual(timezone.localtime(slots[0]['start_time']).time(), time(9, 0))

    def test_closed_day_empty(self):
        tuesday = self.monday + timedelta(days=1)
        slots = AvailabilityService.list_open_slots(
            service=self.service,
            day=tuesday,
            duration_minutes=60,
        )
        self.assertEqual(slots, [])

    def test_exception_closed(self):
        AvailabilityException.objects.create(
            organization=self.org,
            date=self.monday,
            reason='Holiday',
            is_closed=True,
        )
        slots = AvailabilityService.list_open_slots(
            service=self.service,
            day=self.monday,
            duration_minutes=60,
        )
        self.assertEqual(slots, [])

    def test_overlap_removed_and_exclude_booking(self):
        start = timezone.make_aware(
            datetime.combine(self.monday, time(10, 0)),
            timezone.get_current_timezone(),
        )
        booking = Booking.objects.create(
            user=self.customer,
            service=self.service,
            organization=self.org,
            status=Booking.BookingStatus.REQUESTED,
            total_price=Decimal('75.00'),
            accepted_currency=self.cac,
        )
        BookingTimeSlot.objects.create(
            booking=booking,
            start_time=start,
            end_time=start + timedelta(hours=1),
            location_type=Booking.LocationType.OFFICE,
        )
        slots = AvailabilityService.list_open_slots(
            service=self.service,
            day=self.monday,
            duration_minutes=60,
        )
        starts = [timezone.localtime(s['start_time']).time() for s in slots]
        self.assertNotIn(time(10, 0), starts)

        slots_ex = AvailabilityService.list_open_slots(
            service=self.service,
            day=self.monday,
            duration_minutes=60,
            exclude_booking=booking,
        )
        starts_ex = [timezone.localtime(s['start_time']).time() for s in slots_ex]
        self.assertIn(time(10, 0), starts_ex)

    def test_validate_rejects_outside_hours(self):
        start = timezone.make_aware(
            datetime.combine(self.monday, time(14, 0)),
            timezone.get_current_timezone(),
        )
        with self.assertRaises(Exception) as ctx:
            AvailabilityService.validate_slots(
                service=self.service,
                practitioner=None,
                slots=[
                    {
                        'start_time': start,
                        'end_time': start + timedelta(hours=1),
                    }
                ],
            )
        self.assertIn('business hours', str(ctx.exception).lower())

    def test_open_slots_api(self):
        api = APIClient()
        res = api.get(
            f'/api/v1/services/{self.service.id}/open-slots/',
            {'date': self.monday.isoformat(), 'duration_minutes': 60},
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK, res.data)
        self.assertEqual(res.data['date'], self.monday.isoformat())
        self.assertEqual(len(res.data['slots']), 3)
