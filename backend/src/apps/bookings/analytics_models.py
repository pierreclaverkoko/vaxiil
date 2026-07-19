from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.utils import timezone
from django.utils.translation import gettext_lazy as _

from src.apps.core.models import OrganizationMixin, SoftDeleteModel


class BookingAnalytics(SoftDeleteModel, OrganizationMixin):
    """Daily booking analytics for organizations"""
    organization = models.ForeignKey(
        'organizations.Organization',
        on_delete=models.CASCADE,
        related_name='booking_analytics'
    )
    date = models.DateField()
    
    # Booking counts
    total_bookings = models.PositiveIntegerField(default=0)
    confirmed_bookings = models.PositiveIntegerField(default=0)
    completed_bookings = models.PositiveIntegerField(default=0)
    cancelled_bookings = models.PositiveIntegerField(default=0)
    no_show_bookings = models.PositiveIntegerField(default=0)
    
    # Revenue metrics
    total_revenue = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0,
        validators=[MinValueValidator(0)]
    )
    refund_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0,
        validators=[MinValueValidator(0)]
    )
    net_revenue = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0,
        validators=[MinValueValidator(0)]
    )
    
    # Performance metrics
    average_booking_value = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0,
        validators=[MinValueValidator(0)]
    )
    conversion_rate = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        default=0,
        validators=[MinValueValidator(0), MaxValueValidator(100)]
    )
    
    # Service breakdown
    most_booked_service = models.ForeignKey(
        'services.Service',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='analytics_most_booked'
    )
    service_breakdown = models.JSONField(
        default=dict,
        blank=True,
        help_text='Breakdown of bookings by service category'
    )
    
    # Time-based metrics
    peak_hour = models.PositiveSmallIntegerField(
        null=True,
        blank=True,
        validators=[MinValueValidator(0), MaxValueValidator(23)]
    )
    average_booking_duration = models.PositiveIntegerField(
        default=60,
        help_text='Average booking duration in minutes'
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'booking_analytics'
        unique_together = [['organization', 'date']]
        ordering = ['-date']
    
    def __str__(self):
        return f"{self.organization.name} Analytics - {self.date}"
    
    def calculate_conversion_rate(self):
        """Calculate booking conversion rate"""
        if self.total_bookings > 0:
            return (self.confirmed_bookings / self.total_bookings) * 100
        return 0
    
    def calculate_net_revenue(self):
        """Calculate net revenue after refunds"""
        return self.total_revenue - self.refund_amount
    
    def save(self, *args, **kwargs):
        # Auto-calculate derived fields
        self.net_revenue = self.calculate_net_revenue()
        self.conversion_rate = self.calculate_conversion_rate()
        
        if self.total_bookings > 0:
            self.average_booking_value = self.total_revenue / self.total_bookings
        
        super().save(*args, **kwargs)


class PractitionerPerformance(SoftDeleteModel):
    """Performance metrics for individual practitioners"""
    practitioner = models.ForeignKey(
        'users.User',
        on_delete=models.CASCADE,
        related_name='performance_metrics'
    )
    organization = models.ForeignKey(
        'organizations.Organization',
        on_delete=models.CASCADE,
        related_name='practitioner_performance'
    )
    date = models.DateField()
    
    # Performance metrics
    total_bookings = models.PositiveIntegerField(default=0)
    completed_bookings = models.PositiveIntegerField(default=0)
    cancelled_bookings = models.PositiveIntegerField(default=0)
    no_show_bookings = models.PositiveIntegerField(default=0)
    
    # Quality metrics
    average_rating = models.DecimalField(
        max_digits=3,
        decimal_places=2,
        null=True,
        blank=True,
        validators=[MinValueValidator(0), MaxValueValidator(5)]
    )
    total_reviews = models.PositiveIntegerField(default=0)
    
    # Revenue metrics
    total_revenue = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0,
        validators=[MinValueValidator(0)]
    )
    
    # Time metrics
    total_hours_worked = models.DecimalField(
        max_digits=8,
        decimal_places=2,
        default=0,
        validators=[MinValueValidator(0)]
    )
    average_session_duration = models.PositiveIntegerField(
        default=60,
        help_text='Average session duration in minutes'
    )
    
    # Availability metrics
    availability_percentage = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        default=100,
        validators=[MinValueValidator(0), MaxValueValidator(100)]
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'practitioner_performance'
        unique_together = [['practitioner', 'date']]
        ordering = ['-date']
    
    def __str__(self):
        return f"{self.practitioner.email} Performance - {self.date}"
    
    def calculate_completion_rate(self):
        """Calculate booking completion rate"""
        total = self.total_bookings
        if total > 0:
            return (self.completed_bookings / total) * 100
        return 0


class ServiceAnalytics(SoftDeleteModel):
    """Analytics for individual services"""
    service = models.ForeignKey(
        'services.Service',
        on_delete=models.CASCADE,
        related_name='analytics'
    )
    organization = models.ForeignKey(
        'organizations.Organization',
        on_delete=models.CASCADE,
        related_name='service_analytics'
    )
    date = models.DateField()
    
    # Booking metrics
    total_bookings = models.PositiveIntegerField(default=0)
    confirmed_bookings = models.PositiveIntegerField(default=0)
    completed_bookings = models.PositiveIntegerField(default=0)
    
    # Revenue metrics
    total_revenue = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0,
        validators=[MinValueValidator(0)]
    )
    
    # Performance metrics
    average_rating = models.DecimalField(
        max_digits=3,
        decimal_places=2,
        null=True,
        blank=True,
        validators=[MinValueValidator(0), MaxValueValidator(5)]
    )
    
    # Time metrics
    total_duration_minutes = models.PositiveIntegerField(default=0)
    average_duration = models.PositiveIntegerField(default=60)
    
    # Popularity metrics
    booking_trend = models.JSONField(
        default=list,
        blank=True,
        help_text='Booking trend data for the last 30 days'
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'service_analytics'
        unique_together = [['service', 'date']]
        ordering = ['-date']
    
    def __str__(self):
        return f"{self.service.name} Analytics - {self.date}"


class ResourceUtilization(SoftDeleteModel, OrganizationMixin):
    """Track utilization of resources (rooms, equipment)"""

    class ResourceType(models.TextChoices):
        ROOM = 'R', _('Room')
        EQUIPMENT = 'E', _('Equipment')
        FACILITY = 'F', _('Facility')

    organization = models.ForeignKey(
        'organizations.Organization',
        on_delete=models.CASCADE,
        related_name='resource_utilization',
    )
    resource_name = models.CharField(max_length=255)
    resource_type = models.CharField(
        max_length=1,
        choices=ResourceType.choices,
    )
    date = models.DateField()
    
    # Utilization metrics
    total_available_hours = models.DecimalField(
        max_digits=8,
        decimal_places=2,
        default=0,
        validators=[MinValueValidator(0)]
    )
    total_booked_hours = models.DecimalField(
        max_digits=8,
        decimal_places=2,
        default=0,
        validators=[MinValueValidator(0)]
    )
    
    # Calculated metrics
    utilization_percentage = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        default=0,
        validators=[MinValueValidator(0), MaxValueValidator(100)]
    )
    
    # Revenue metrics
    revenue_per_hour = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0,
        validators=[MinValueValidator(0)]
    )
    
    # Peak usage data
    peak_hours = models.JSONField(
        default=list,
        blank=True,
        help_text='Peak usage hours throughout the day'
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'resource_utilization'
        unique_together = [['organization', 'resource_name', 'date']]
        ordering = ['-date']
    
    def __str__(self):
        return f"{self.resource_name} Utilization - {self.date}"
    
    def calculate_utilization(self):
        """Calculate utilization percentage"""
        if self.total_available_hours > 0:
            return (self.total_booked_hours / self.total_available_hours) * 100
        return 0
    
    def save(self, *args, **kwargs):
        # Auto-calculate utilization percentage
        self.utilization_percentage = self.calculate_utilization()
        
        if self.total_booked_hours > 0:
            self.revenue_per_hour = self.total_revenue / self.total_booked_hours
        
        super().save(*args, **kwargs)
