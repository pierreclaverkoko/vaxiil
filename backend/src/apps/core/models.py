import uuid
from django.db import models
from django.utils import timezone
from django.contrib.postgres.fields import ArrayField


class SoftDeleteManager(models.Manager):
    def get_queryset(self):
        return super().get_queryset().filter(deleted_at__isnull=True)


class SoftDeleteModel(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    deleted_at = models.DateTimeField(null=True, blank=True)

    objects = SoftDeleteManager()
    all_objects = models.Manager()

    class Meta:
        abstract = True

    def delete(self, using=None, keep_parents=False):
        self.deleted_at = timezone.now()
        self.save(using=using)

    def hard_delete(self, using=None, keep_parents=False):
        super().delete(using=using, keep_parents=keep_parents)


class TimeStampedModel(models.Model):
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True


class OrganizationMixin(models.Model):
    organization = models.ForeignKey(
        'organizations.Organization',
        on_delete=models.CASCADE,
        related_name='%(class)s_set'
    )

    class Meta:
        abstract = True


class LocationModel(models.Model):
    address = models.CharField(max_length=255)
    city = models.CharField(max_length=100)
    postal_code = models.CharField(max_length=20)
    country = models.CharField(max_length=100)
    latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)

    class Meta:
        abstract = True


class AvailabilityMixin(models.Model):
    """Mixin for availability-related fields and methods."""
    
    class DayOfWeek(models.TextChoices):
        MONDAY = 'MONDAY', 'Monday'
        TUESDAY = 'TUESDAY', 'Tuesday'
        WEDNESDAY = 'WEDNESDAY', 'Wednesday'
        THURSDAY = 'THURSDAY', 'Thursday'
        FRIDAY = 'FRIDAY', 'Friday'
        SATURDAY = 'SATURDAY', 'Saturday'
        SUNDAY = 'SUNDAY', 'Sunday'
    
    # Availability Options
    max_bookings_per_day = models.PositiveIntegerField(
        default=10,
        validators=[models.MinValueValidator(1), models.MaxValueValidator(100)],
        help_text='Maximum bookings allowed per day'
    )
    max_bookings_per_time_slot = models.PositiveIntegerField(
        default=1,
        validators=[models.MinValueValidator(1), models.MaxValueValidator(20)],
        help_text='Maximum bookings per time slot'
    )
    booking_advance_days = models.PositiveIntegerField(
        default=30,
        validators=[models.MinValueValidator(1), models.MaxValueValidator(365)],
        help_text='Days in advance bookings can be made'
    )
    minimum_booking_hours = models.PositiveIntegerField(
        default=2,
        validators=[models.MinValueValidator(0), models.MaxValueValidator(168)],
        help_text='Minimum hours before booking time'
    )
    cancellation_hours = models.PositiveIntegerField(
        default=24,
        validators=[models.MinValueValidator(0), models.MaxValueValidator(168)],
        help_text='Hours before booking for cancellation'
    )
    
    # Time-based availability
    available_start_time = models.TimeField(
        null=True,
        blank=True,
        help_text='Earliest time this can be booked'
    )
    available_end_time = models.TimeField(
        null=True,
        blank=True,
        help_text='Latest time this can be booked'
    )
    
    # Day-based availability using ArrayField
    available_days = ArrayField(
        models.CharField(max_length=10, choices=DayOfWeek.choices),
        default=list,
        blank=True,
        help_text='Days of the week when available'
    )
    
    # Seasonal availability
    seasonal_start_date = models.DateField(
        null=True,
        blank=True,
        help_text='Start date for seasonal availability'
    )
    seasonal_end_date = models.DateField(
        null=True,
        blank=True,
        help_text='End date for seasonal availability'
    )
    
    # Availability notes
    availability_notes = models.TextField(
        blank=True,
        help_text='Notes about availability or special conditions'
    )
    
    class Meta:
        abstract = True
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Set default available days if not provided
        if not self.available_days:
            self.available_days = [
                self.DayOfWeek.MONDAY,
                self.DayOfWeek.TUESDAY,
                self.DayOfWeek.WEDNESDAY,
                self.DayOfWeek.THURSDAY,
                self.DayOfWeek.FRIDAY,
                self.DayOfWeek.SATURDAY,
                self.DayOfWeek.SUNDAY,
            ]
    
    def is_available_on_day(self, date):
        """Check if available on a specific day."""
        # Check day of week availability
        weekday_mapping = {
            0: self.DayOfWeek.MONDAY,
            1: self.DayOfWeek.TUESDAY,
            2: self.DayOfWeek.WEDNESDAY,
            3: self.DayOfWeek.THURSDAY,
            4: self.DayOfWeek.FRIDAY,
            5: self.DayOfWeek.SATURDAY,
            6: self.DayOfWeek.SUNDAY,
        }
        
        day_of_week = weekday_mapping.get(date.weekday())
        if day_of_week not in (self.available_days or []):
            return False
        
        # Check seasonal availability
        if self.seasonal_start_date and self.seasonal_end_date:
            if not (self.seasonal_start_date <= date <= self.seasonal_end_date):
                return False
        
        return True
    
    def is_available_at_time(self, datetime_obj):
        """Check if available at a specific time."""
        if not self.is_available_on_day(datetime_obj.date()):
            return False
        
        # Check time constraints
        if self.available_start_time and self.available_end_time:
            time = datetime_obj.time()
            if not (self.available_start_time <= time <= self.available_end_time):
                return False
        
        return True
    
    def can_be_booked_in_advance(self, booking_date):
        """Check if booking date is within advance booking window."""
        today = timezone.now().date()
        days_ahead = (booking_date - today).days
        
        return 0 <= days_ahead <= self.booking_advance_days
    
    def get_available_days_of_week(self):
        """Get list of available days of week."""
        days = []
        day_order = [
            self.DayOfWeek.MONDAY,
            self.DayOfWeek.TUESDAY,
            self.DayOfWeek.WEDNESDAY,
            self.DayOfWeek.THURSDAY,
            self.DayOfWeek.FRIDAY,
            self.DayOfWeek.SATURDAY,
            self.DayOfWeek.SUNDAY,
        ]
        
        for day in day_order:
            if day in (self.available_days or []):
                days.append((day.value, day.label))
        
        return days
    
    def set_available_days(self, days):
        """Set available days from a list of day values or DayOfWeek enums."""
        if not days:
            self.available_days = []
            return
        
        # Convert string values to DayOfWeek enums if needed
        available_days = []
        for day in days:
            if isinstance(day, str):
                try:
                    available_days.append(self.DayOfWeek(day))
                except ValueError:
                    continue
            elif isinstance(day, self.DayOfWeek):
                available_days.append(day)
        
        self.available_days = available_days


class MultiTenantMixin(models.Model):
    def get_queryset(self):
        if hasattr(self, 'request') and hasattr(self.request, 'organization'):
            return super().get_queryset().filter(organization=self.request.organization)
        return super().get_queryset()

    class Meta:
        abstract = True
