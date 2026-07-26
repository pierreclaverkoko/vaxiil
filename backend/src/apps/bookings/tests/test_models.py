from datetime import time

from django.contrib.auth import get_user_model
from django.test import TestCase

from src.apps.bookings.models import (
    AvailabilityException,
    Booking,
    BusinessHours,
)
from src.apps.finances.models import Currency
from src.apps.organizations.models import (
    Country,
    CountryAcceptedCurrency,
    Organization,
    OrganizationAddress,
    OrganizationTypeModel,
)
from src.apps.services.models import Service, ServiceCategory, ServiceSubCategory
from src.apps.test_helpers.geo import seed_cities_country, seed_us_country_and_currency, create_org_address

User = get_user_model()


def _seed_us():
    return seed_us_country_and_currency()




class BookingModelTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            email='customer@example.com',
            username='customer',
            password='testpass123',
        )
        self.org_type = OrganizationTypeModel.objects.create(
            name='spa',
            display_name='Spa',
        )
        self.country, self.cac = _seed_us()
        self.organization = Organization.objects.create(
            name='Test Spa',
            type=self.org_type,
            email='spa@example.com',
            country=self.country,
            default_currency=self.cac,
        )
        create_org_address(self.organization, self.country, address='1 Main', city='NYC', postal_code='10001')
        self.category = ServiceCategory.objects.create(name='Massage')
        self.subcategory = ServiceSubCategory.objects.create(
            name='Swedish Massage',
            category=self.category,
        )
        self.service = Service.objects.create(
            cities_city=seed_cities_country(city_name='NYC')[1],
            
            name='Swedish Massage',
            sub_category=self.subcategory,
            organization=self.organization,
            description='Relaxing',
            price_min=50,
            price_max=100,
            accepted_currency=self.cac,
            address='1 Main',
            postal_code='10001',
            country_text='US',
            country=self.country,
        )

    def test_booking_creation(self):
        booking = Booking.objects.create(
            user=self.user,
            service=self.service,
            organization=self.organization,
            status=Booking.BookingStatus.REQUESTED,
            total_price=75.00,
            accepted_currency=self.cac,
        )
        self.assertEqual(booking.user, self.user)
        self.assertEqual(booking.service, self.service)
        self.assertEqual(booking.organization, self.organization)

    def test_booking_str_representation(self):
        booking = Booking.objects.create(
            user=self.user,
            service=self.service,
            organization=self.organization,
            status=Booking.BookingStatus.DRAFT,
            total_price=50.00,
            accepted_currency=self.cac,
        )
        self.assertIn(str(booking.id), str(booking))


class BusinessHoursTests(TestCase):
    def setUp(self):
        self.org_type = OrganizationTypeModel.objects.create(
            name='spa',
            display_name='Spa',
        )
        self.country, self.cac = _seed_us()
        self.organization = Organization.objects.create(
            name='Test Spa',
            type=self.org_type,
            email='spa@example.com',
            country=self.country,
            default_currency=self.cac,
        )

    def test_business_hours_creation(self):
        business_hours = BusinessHours.objects.create(
            organization=self.organization,
            day_of_week=BusinessHours.Weekday.MONDAY,
            open_time=time(9, 0),
            close_time=time(18, 0),
            is_closed=False,
        )
        self.assertEqual(business_hours.organization, self.organization)


class AvailabilityExceptionTests(TestCase):
    def setUp(self):
        self.org_type = OrganizationTypeModel.objects.create(
            name='spa',
            display_name='Spa',
        )
        self.country, self.cac = _seed_us()
        self.organization = Organization.objects.create(
            name='Test Spa',
            type=self.org_type,
            email='spa@example.com',
            country=self.country,
            default_currency=self.cac,
        )

    def test_availability_exception_creation(self):
        from datetime import date

        exception_date = date(2024, 12, 25)
        availability_exception = AvailabilityException.objects.create(
            organization=self.organization,
            date=exception_date,
            is_closed=True,
            reason='Christmas Holiday',
        )
        self.assertEqual(availability_exception.organization, self.organization)
        self.assertEqual(availability_exception.date, exception_date)
