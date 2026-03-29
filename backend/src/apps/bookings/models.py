from django.db import models
from django.core.validators import MinValueValidator, MaxValueValidator
from django.utils import timezone
from src.apps.core.models import SoftDeleteModel, OrganizationMixin


class BookingStatus(models.TextChoices):
    """Booking status choices."""
    DRAFT = 'DRAFT', 'Draft'
    REQUESTED = 'REQUESTED', 'Requested'
    CONFIRMED = 'CONFIRMED', 'Confirmed'
    IN_PROGRESS = 'IN_PROGRESS', 'In Progress'
    COMPLETED = 'COMPLETED', 'Completed'
    CANCELLED = 'CANCELLED', 'Cancelled'
    NO_SHOW = 'NO_SHOW', 'No Show'
    RESCHEDULED = 'RESCHEDULED', 'Rescheduled'


class LocationType(models.TextChoices):
    """Booking location types."""
    OFFICE = 'OFFICE', 'At Office/Business Location'
    HOME = 'HOME', 'At Client Home'
    VIRTUAL = 'VIRTUAL', 'Virtual/Online'
    MOBILE = 'MOBILE', 'Mobile Service'


class BusinessHours(SoftDeleteModel):
    """Organization business hours."""
    
    DAYS_OF_WEEK = [
        (0, 'Monday'),
        (1, 'Tuesday'),
        (2, 'Wednesday'),
        (3, 'Thursday'),
        (4, 'Friday'),
        (5, 'Saturday'),
        (6, 'Sunday'),
    ]
    
    organization = models.ForeignKey(
        'organizations.Organization',
        on_delete=models.CASCADE,
        related_name='business_hours'
    )
    day_of_week = models.PositiveSmallIntegerField(choices=DAYS_OF_WEEK)
    open_time = models.TimeField()
    close_time = models.TimeField()
    is_closed = models.BooleanField(default=False)
    
    class Meta:
        db_table = 'business_hours'
        unique_together = [['organization', 'day_of_week']]
        ordering = ['day_of_week']
        indexes = [
            models.Index(fields=['organization']),
            models.Index(fields=['day_of_week']),
        ]
    
    def __str__(self):
        day_name = dict(self.DAYS_OF_WEEK).get(self.day_of_week, 'Unknown')
        return f"{self.organization.name} - {day_name}"


class AvailabilityException(SoftDeleteModel):
    """Organization availability exceptions."""
    
    EXCEPTION_TYPES = [
        ('HOLIDAY', 'Holiday'),
        ('MAINTENANCE', 'Maintenance'),
        ('PRIVATE_EVENT', 'Private Event'),
        ('WEATHER', 'Weather Related'),
        ('OTHER', 'Other'),
    ]
    
    organization = models.ForeignKey(
        'organizations.Organization',
        on_delete=models.CASCADE,
        related_name='availability_exceptions'
    )
    date = models.DateField()
    reason = models.CharField(max_length=255)
    exception_type = models.CharField(
        max_length=20,
        choices=EXCEPTION_TYPES,
        default='OTHER'
    )
    is_closed = models.BooleanField(default=True)
    alternate_hours = models.JSONField(
        default=dict,
        blank=True,
        help_text='Alternative hours for this date'
    )
    
    class Meta:
        db_table = 'availability_exceptions'
        ordering = ['date']
        indexes = [
            models.Index(fields=['organization']),
            models.Index(fields=['date']),
            models.Index(fields=['exception_type']),
        ]
    
    def __str__(self):
        return f"{self.organization.name} - {self.date} ({self.reason})"


class PractitionerAvailability(SoftDeleteModel):
    """Practitioner availability schedule."""
    
    user = models.ForeignKey(
        'users.User',
        on_delete=models.CASCADE,
        related_name='practitioner_availability'
    )
    date = models.DateField()
    time_slots = models.JSONField(
        default=list,
        help_text='List of available time slots [{"start": "09:00", "end": "10:30"}]'
    )
    max_bookings = models.PositiveIntegerField(
        default=1,
        validators=[MinValueValidator(1)]
    )
    location_type = models.CharField(
        max_length=10,
        choices=LocationType.choices,
        default=LocationType.OFFICE
    )
    notes = models.TextField(blank=True)
    
    class Meta:
        db_table = 'practitioner_availability'
        unique_together = [['user', 'date']]
        ordering = ['-date']
        indexes = [
            models.Index(fields=['user']),
            models.Index(fields=['date']),
            models.Index(fields=['location_type']),
        ]
    
    def __str__(self):
        return f"{self.user.email} - {self.date}"


class ResourceAvailability(SoftDeleteModel):
    """Resource availability for bookings."""
    
    RESOURCE_TYPES = [
        ('ROOM', 'Room'),
        ('EQUIPMENT', 'Equipment'),
        ('FACILITY', 'Facility'),
    ]
    
    organization = models.ForeignKey(
        'organizations.Organization',
        on_delete=models.CASCADE,
        related_name='resource_availability'
    )
    name = models.CharField(max_length=255)
    resource_type = models.CharField(
        max_length=15,
        choices=RESOURCE_TYPES
    )
    date = models.DateField()
    time_slots = models.JSONField(
        default=list,
        help_text='List of available time slots [{"start": "09:00", "end": "10:30"}]'
    )
    capacity = models.PositiveIntegerField(
        default=1,
        validators=[MinValueValidator(1)]
    )
    location_details = models.JSONField(
        default=dict,
        blank=True,
        help_text='Location details like room number, floor, etc.'
    )
    
    class Meta:
        db_table = 'resource_availability'
        unique_together = [['organization', 'name', 'date']]
        ordering = ['-date', 'resource_type', 'name']
        indexes = [
            models.Index(fields=['organization']),
            models.Index(fields=['date']),
            models.Index(fields=['resource_type']),
            models.Index(fields=['name']),
        ]
    
    def __str__(self):
        return f"{self.organization.name} - {self.name} ({self.date})"


class Booking(SoftDeleteModel, OrganizationMixin):
    """Main booking model."""
    
    user = models.ForeignKey(
        'users.User',
        on_delete=models.CASCADE,
        related_name='bookings'
    )
    service = models.ForeignKey(
        'services.Service',
        on_delete=models.CASCADE,
        related_name='bookings'
    )
    organization = models.ForeignKey(
        'organizations.Organization',
        on_delete=models.CASCADE,
        related_name='bookings'
    )
    practitioner = models.ForeignKey(
        'users.User',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='practitioner_bookings'
    )
    status = models.CharField(
        max_length=20,
        choices=BookingStatus.choices,
        default=BookingStatus.DRAFT
    )
    practitioner_alias = models.CharField(
        max_length=100,
        blank=True,
        help_text='Alias for practitioner when user requests specific person'
    )
    total_price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        validators=[MinValueValidator(0)]
    )
    currency = models.CharField(max_length=3, default='USD')
    special_requests = models.TextField(blank=True)
    internal_notes = models.TextField(blank=True)
    confirmed_at = models.DateTimeField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    cancelled_at = models.DateTimeField(null=True, blank=True)
    cancellation_reason = models.TextField(blank=True)
    
    class Meta:
        db_table = 'bookings'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user']),
            models.Index(fields=['service']),
            models.Index(fields=['organization']),
            models.Index(fields=['practitioner']),
            models.Index(fields=['status']),
            models.Index(fields=['created_at']),
            models.Index(fields=['confirmed_at']),
            models.Index(fields=['deleted_at']),
        ]
    
    def __str__(self):
        return f"Booking {self.id} - {self.user.email} - {self.service.name}"
    
    def confirm(self):
        """Confirm booking."""
        self.status = BookingStatus.CONFIRMED
        self.confirmed_at = timezone.now()
        self.save()
    
    def complete(self):
        """Complete booking."""
        self.status = BookingStatus.COMPLETED
        self.completed_at = timezone.now()
        self.save()
    
    def cancel(self, reason=''):
        """Cancel booking."""
        self.status = BookingStatus.CANCELLED
        self.cancelled_at = timezone.now()
        self.cancellation_reason = reason
        self.save()


class BookingTimeSlot(SoftDeleteModel):
    """Individual time slots for bookings."""
    
    booking = models.ForeignKey(
        Booking,
        on_delete=models.CASCADE,
        related_name='time_slots'
    )
    start_time = models.DateTimeField()
    end_time = models.DateTimeField()
    location_type = models.CharField(
        max_length=10,
        choices=LocationType.choices,
        default=LocationType.OFFICE
    )
    address = models.CharField(max_length=255, blank=True)
    room_details = models.CharField(max_length=255, blank=True)
    virtual_meeting_link = models.URLField(blank=True)
    notes = models.TextField(blank=True)
    
    class Meta:
        db_table = 'booking_time_slots'
        ordering = ['start_time']
        indexes = [
            models.Index(fields=['booking']),
            models.Index(fields=['start_time']),
            models.Index(fields=['end_time']),
            models.Index(fields=['location_type']),
        ]
    
    def __str__(self):
        return f"{self.booking.id} - {self.start_time} to {self.end_time}"


class BookingLog(SoftDeleteModel):
    """Audit log for booking status changes."""
    
    booking = models.ForeignKey(
        Booking,
        on_delete=models.CASCADE,
        related_name='logs'
    )
    old_status = models.CharField(
        max_length=20,
        choices=BookingStatus.choices,
        blank=True
    )
    new_status = models.CharField(
        max_length=20,
        choices=BookingStatus.choices
    )
    changed_by = models.ForeignKey(
        'users.User',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='booking_changes'
    )
    notes = models.TextField(blank=True)
    timestamp = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        db_table = 'booking_logs'
        ordering = ['-timestamp']
        indexes = [
            models.Index(fields=['booking']),
            models.Index(fields=['changed_by']),
            models.Index(fields=['timestamp']),
            models.Index(fields=['new_status']),
        ]
    
    def __str__(self):
        return f"Booking {self.booking.id} - {self.old_status} to {self.new_status}"
