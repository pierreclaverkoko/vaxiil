from django.test import TestCase
from django.contrib.auth import get_user_model
from datetime import date, time, datetime, timedelta
from django.utils import timezone
from ..models import (
    BookingStatus, LocationType, BusinessHours, AvailabilityException,
    PractitionerAvailability, ResourceAvailability, Booking, BookingTimeSlot
)
from ..organizations.models import Organization, OrganizationTypeModel
from ..services.models import Service, ServiceCategory, ServiceSubCategory

User = get_user_model()


class BookingModelTests(TestCase):
    """Test cases for Booking models."""
    
    def setUp(self):
        """Set up test data."""
        self.user = User.objects.create_user(
            email='customer@example.com',
            username='customer',
            password='testpass123'
        )
        
        self.org_type = OrganizationTypeModel.objects.create(
            name='spa',
            display_name='Spa'
        )
        
        self.organization = Organization.objects.create(
            name='Test Spa',
            type=self.org_type,
            email='spa@example.com'
        )
        
        self.category = ServiceCategory.objects.create(name='Massage')
        self.subcategory = ServiceSubCategory.objects.create(
            name='Swedish Massage',
            category=self.category
        )
        
        self.service = Service.objects.create(
            name='Swedish Massage',
            sub_category=self.subcategory,
            organization=self.organization,
            description='Relaxing Swedish massage',
            price_min=50,
            price_max=100
        )
    
    def test_booking_status_choices(self):
        """Test booking status choices."""
        self.assertIn(BookingStatus.PENDING, dict(BookingStatus.choices).values())
        self.assertIn(BookingStatus.CONFIRMED, dict(BookingStatus.choices).values())
        self.assertIn(BookingStatus.CANCELLED, dict(BookingStatus.choices).values())
        self.assertIn(BookingStatus.COMPLETED, dict(BookingStatus.choices).values())
    
    def test_booking_creation(self):
        """Test booking creation."""
        booking = Booking.objects.create(
            customer=self.user,
            service=self.service,
            organization=self.organization,
            booking_date=timezone.now().date() + timedelta(days=1),
            start_time=time(10, 0),
            end_time=time(11, 0),
            status=BookingStatus.PENDING,
            total_amount=75.00
        )
        
        self.assertEqual(booking.customer, self.user)
        self.assertEqual(booking.service, self.service)
        self.assertEqual(booking.organization, self.organization)
        self.assertEqual(booking.status, BookingStatus.PENDING)
        self.assertEqual(booking.total_amount, 75.00)
    
    def test_booking_str_representation(self):
        """Test booking string representation."""
        booking_date = timezone.now().date() + timedelta(days=1)
        booking = Booking.objects.create(
            customer=self.user,
            service=self.service,
            organization=self.organization,
            booking_date=booking_date,
            start_time=time(10, 0),
            end_time=time(11, 0),
            status=BookingStatus.PENDING,
            total_amount=75.00
        )
        
        expected = f"{self.service.name} - {self.user.email} - {booking_date}"
        self.assertEqual(str(booking), expected)


class BusinessHoursTests(TestCase):
    """Test cases for BusinessHours model."""
    
    def setUp(self):
        """Set up test data."""
        self.org_type = OrganizationTypeModel.objects.create(
            name='spa',
            display_name='Spa'
        )
        
        self.organization = Organization.objects.create(
            name='Test Spa',
            type=self.org_type,
            email='spa@example.com'
        )
    
    def test_business_hours_creation(self):
        """Test business hours creation."""
        business_hours = BusinessHours.objects.create(
            organization=self.organization,
            day_of_week=1,  # Monday
            opening_time=time(9, 0),
            closing_time=time(18, 0),
            is_closed=False
        )
        
        self.assertEqual(business_hours.organization, self.organization)
        self.assertEqual(business_hours.day_of_week, 1)
        self.assertEqual(business_hours.opening_time, time(9, 0))
        self.assertEqual(business_hours.closing_time, time(18, 0))
        self.assertFalse(business_hours.is_closed)
    
    def test_business_hours_str_representation(self):
        """Test business hours string representation."""
        business_hours = BusinessHours.objects.create(
            organization=self.organization,
            day_of_week=1,  # Monday
            opening_time=time(9, 0),
            closing_time=time(18, 0),
            is_closed=False
        )
        
        expected = f"{self.organization.name} - Monday - 09:00 to 18:00"
        self.assertEqual(str(business_hours), expected)


class AvailabilityExceptionTests(TestCase):
    """Test cases for AvailabilityException model."""
    
    def setUp(self):
        """Set up test data."""
        self.org_type = OrganizationTypeModel.objects.create(
            name='spa',
            display_name='Spa'
        )
        
        self.organization = Organization.objects.create(
            name='Test Spa',
            type=self.org_type,
            email='spa@example.com'
        )
    
    def test_availability_exception_creation(self):
        """Test availability exception creation."""
        exception_date = date(2024, 12, 25)  # Christmas
        availability_exception = AvailabilityException.objects.create(
            organization=self.organization,
            exception_date=exception_date,
            is_closed=True,
            reason='Christmas Holiday'
        )
        
        self.assertEqual(availability_exception.organization, self.organization)
        self.assertEqual(availability_exception.exception_date, exception_date)
        self.assertTrue(availability_exception.is_closed)
        self.assertEqual(availability_exception.reason, 'Christmas Holiday')
    
    def test_availability_exception_str_representation(self):
        """Test availability exception string representation."""
        exception_date = date(2024, 12, 25)
        availability_exception = AvailabilityException.objects.create(
            organization=self.organization,
            exception_date=exception_date,
            is_closed=True,
            reason='Christmas Holiday'
        )
        
        expected = f"{self.organization.name} - {exception_date} - Closed"
        self.assertEqual(str(availability_exception), expected)
