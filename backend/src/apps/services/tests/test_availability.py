from datetime import date, datetime, time, timedelta

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone

from src.apps.core.models import AvailabilityMixin
from src.apps.organizations.models import Organization, OrganizationTypeModel
from src.apps.test_helpers.geo import seed_cities_country,  create_org_address, seed_us_country_and_currency
from src.apps.services.models import (
    Service,
    ServiceCategory,
    ServiceSubCategory,
)

User = get_user_model()


class ServiceAvailabilityTests(TestCase):
    """Test cases for Service availability functionality."""
    
    def setUp(self):
        """Set up test data."""
        self.user = User.objects.create_user(
            email='test@example.com',
            username='testuser',
            password='testpass123',
            role=User.UserRole.CLIENT,
        )

        self.org_type = OrganizationTypeModel.objects.create(
            name='spa',
            display_name='Spa',
        )

        self.country, self.cac = seed_us_country_and_currency()
        self.organization = Organization.objects.create(
            name='Test Spa',
            type=self.org_type,
            email='spa@example.com',
            country=self.country,
            default_currency=self.cac,
        )
        create_org_address(
            self.organization,
            self.country,
            address='1 Main',
            city='C',
            postal_code='0',
        )
        
        self.category = ServiceCategory.objects.create(name='Massage')
        self.subcategory = ServiceSubCategory.objects.create(
            name='Swedish Massage',
            category=self.category
        )
        
        self.service = Service.objects.create(
            cities_city=seed_cities_country(city_name='C')[1],
            
            name='Swedish Massage',
            sub_category=self.subcategory,
            organization=self.organization,
            description='Relaxing Swedish massage',
            price_min=50,
            price_max=100,
            accepted_currency=self.cac,
            address='1 Main',
            postal_code='0',
            country_text='US',
            country=self.country,
            availability_type=Service.ServiceAvailabilityType.APPOINTMENT,
        )
    
    def test_service_availability_type_choices(self):
        """Test service availability type choices."""
        AT = Service.ServiceAvailabilityType
        self.assertIn(AT.ALWAYS, dict(AT.choices).values())
        self.assertIn(AT.SCHEDULED, dict(AT.choices).values())
        self.assertIn(AT.ON_DEMAND, dict(AT.choices).values())
        self.assertIn(AT.APPOINTMENT, dict(AT.choices).values())

    def test_service_default_availability_settings(self):
        """Test default availability settings."""
        self.assertEqual(self.service.availability_type, Service.ServiceAvailabilityType.APPOINTMENT)
        self.assertEqual(self.service.max_bookings_per_day, 10)
        self.assertEqual(self.service.max_bookings_per_time_slot, 1)
        self.assertEqual(self.service.booking_advance_days, 30)
        self.assertEqual(self.service.minimum_booking_hours, 2)
        self.assertEqual(self.service.cancellation_hours, 24)
        
        # All days should be available by default
        expected = {d.value for d in [
            AvailabilityMixin.DayOfWeek.MONDAY,
            AvailabilityMixin.DayOfWeek.TUESDAY,
            AvailabilityMixin.DayOfWeek.WEDNESDAY,
            AvailabilityMixin.DayOfWeek.THURSDAY,
            AvailabilityMixin.DayOfWeek.FRIDAY,
            AvailabilityMixin.DayOfWeek.SATURDAY,
            AvailabilityMixin.DayOfWeek.SUNDAY,
        ]}
        self.assertEqual(set(self.service.available_days), expected)
    
    def test_is_available_on_day_weekday(self):
        """Test availability on weekdays."""
        # Monday (weekday 0)
        monday_date = date(2024, 1, 8)  # This is a Monday
        self.assertTrue(self.service.is_available_on_day(monday_date))
        
        # Remove Monday from available days
        available_days = list(self.service.available_days)
        mon = AvailabilityMixin.DayOfWeek.MONDAY.value
        if mon in available_days:
            available_days.remove(mon)
        self.service.available_days = available_days
        self.service.save()
        self.assertFalse(self.service.is_available_on_day(monday_date))
    
    def test_is_available_on_day_weekend(self):
        """Test availability on weekends."""
        # Sunday (weekday 6)
        sunday_date = date(2024, 1, 7)  # This is a Sunday
        self.assertTrue(self.service.is_available_on_day(sunday_date))
        
        # Remove Sunday from available days
        available_days = list(self.service.available_days)
        sun = AvailabilityMixin.DayOfWeek.SUNDAY.value
        if sun in available_days:
            available_days.remove(sun)
        self.service.available_days = available_days
        self.service.save()
        self.assertFalse(self.service.is_available_on_day(sunday_date))
    
    def test_seasonal_availability(self):
        """Test seasonal availability constraints."""
        # Set seasonal dates
        self.service.seasonal_start_date = date(2024, 6, 1)  # June 1
        self.service.seasonal_end_date = date(2024, 8, 31)    # August 31
        self.service.save()
        
        # Date within season
        summer_date = date(2024, 7, 15)
        self.assertTrue(self.service.is_available_on_day(summer_date))
        
        # Date outside season
        winter_date = date(2024, 12, 15)
        self.assertFalse(self.service.is_available_on_day(winter_date))
    
    def test_is_available_at_time(self):
        """Test time-based availability."""
        # Set time constraints
        self.service.available_start_time = time(9, 0)   # 9:00 AM
        self.service.available_end_time = time(17, 0)    # 5:00 PM
        self.service.save()
        
        # Time within constraints
        valid_datetime = datetime(2024, 1, 8, 14, 0)  # 2:00 PM
        self.assertTrue(self.service.is_available_at_time(valid_datetime))
        
        # Time outside constraints
        early_datetime = datetime(2024, 1, 8, 8, 0)   # 8:00 AM
        self.assertFalse(self.service.is_available_at_time(early_datetime))
        
        late_datetime = datetime(2024, 1, 8, 18, 0)    # 6:00 PM
        self.assertFalse(self.service.is_available_at_time(late_datetime))
    
    def test_can_be_booked_in_advance(self):
        """Test advance booking constraints."""
        today = timezone.now().date()
        
        # Within booking window (15 days ahead)
        valid_date = today + timedelta(days=15)
        self.assertTrue(self.service.can_be_booked_in_advance(valid_date))
        
        # Outside booking window (too far ahead)
        invalid_date = today + timedelta(days=45)
        self.assertFalse(self.service.can_be_booked_in_advance(invalid_date))
        
        # Past date
        past_date = today - timedelta(days=1)
        self.assertFalse(self.service.can_be_booked_in_advance(past_date))
    
    def test_get_available_days_of_week(self):
        """Test getting available days of week."""
        # Default: all days available
        days = self.service.get_available_days_of_week()
        self.assertEqual(len(days), 7)
        
        # Remove some days
        available_days = list(self.service.available_days)
        for day in [
            AvailabilityMixin.DayOfWeek.MONDAY,
            AvailabilityMixin.DayOfWeek.SATURDAY,
            AvailabilityMixin.DayOfWeek.SUNDAY,
        ]:
            v = day.value
            if v in available_days:
                available_days.remove(v)
        self.service.available_days = available_days
        self.service.save()
        
        days = self.service.get_available_days_of_week()
        self.assertEqual(len(days), 4)
        
        # Check that the right days are available
        day_values = [day[0] for day in days]
        self.assertIn('T', day_values)
        self.assertIn('W', day_values)
        self.assertIn('H', day_values)
        self.assertIn('F', day_values)
        self.assertNotIn('M', day_values)
        self.assertNotIn('S', day_values)
        self.assertNotIn('U', day_values)
    
    def test_set_available_days(self):
        """Test setting available days."""
        # Set specific days
        self.service.set_available_days([
            AvailabilityMixin.DayOfWeek.MONDAY,
            AvailabilityMixin.DayOfWeek.WEDNESDAY,
            AvailabilityMixin.DayOfWeek.FRIDAY
        ])
        self.service.save()
        
        days = self.service.get_available_days_of_week()
        self.assertEqual(len(days), 3)
        
        day_values = [day[0] for day in days]
        self.assertIn('M', day_values)
        self.assertIn('W', day_values)
        self.assertIn('F', day_values)
        self.assertNotIn('T', day_values)
        self.assertNotIn('H', day_values)
        self.assertNotIn('S', day_values)
        self.assertNotIn('U', day_values)
        
        # Test with string values
        self.service.set_available_days(['MONDAY', 'TUESDAY'])
        self.service.save()
        
        days = self.service.get_available_days_of_week()
        self.assertEqual(len(days), 2)
    
    def test_combined_availability_constraints(self):
        """Test multiple availability constraints working together."""
        # Set up constraints
        self.service.set_available_days([
            AvailabilityMixin.DayOfWeek.TUESDAY,
            AvailabilityMixin.DayOfWeek.WEDNESDAY,
            AvailabilityMixin.DayOfWeek.THURSDAY,
            AvailabilityMixin.DayOfWeek.FRIDAY
        ])
        self.service.available_start_time = time(10, 0)
        self.service.available_end_time = time(16, 0)
        self.service.seasonal_start_date = date(2024, 6, 1)
        self.service.seasonal_end_date = date(2024, 8, 31)
        self.service.save()
        
        # Monday in summer, right time - should be false (Monday not available)
        monday_summer = datetime(2024, 7, 8, 14, 0)
        self.assertFalse(self.service.is_available_at_time(monday_summer))
        
        # Tuesday in winter, right time - should be false (outside season)
        tuesday_winter = datetime(2024, 12, 10, 14, 0)
        self.assertFalse(self.service.is_available_at_time(tuesday_winter))
        
        # Tuesday in summer, right time - should be true
        tuesday_summer = datetime(2024, 7, 9, 14, 0)
        self.assertTrue(self.service.is_available_at_time(tuesday_summer))
        
        # Tuesday in summer, wrong time - should be false
        tuesday_summer_early = datetime(2024, 7, 9, 8, 0)
        self.assertFalse(self.service.is_available_at_time(tuesday_summer_early))
    
    def test_booking_constraints_validation(self):
        """Test booking constraint field validation."""
        # Test valid values
        service = Service.objects.create(
            cities_city=seed_cities_country(city_name='C')[1],
            
            name='Test Service',
            sub_category=self.subcategory,
            organization=self.organization,
            description='Test description',
            price_min=50,
            price_max=100,
            accepted_currency=self.cac,
            address='1 Main',
            postal_code='0',
            country_text='US',
            country=self.country,
            max_bookings_per_day=50,
            max_bookings_per_time_slot=5,
            booking_advance_days=180,
            minimum_booking_hours=0,
            cancellation_hours=0,
        )
        
        self.assertEqual(service.max_bookings_per_day, 50)
        self.assertEqual(service.max_bookings_per_time_slot, 5)
        self.assertEqual(service.booking_advance_days, 180)
        self.assertEqual(service.minimum_booking_hours, 0)
        self.assertEqual(service.cancellation_hours, 0)
