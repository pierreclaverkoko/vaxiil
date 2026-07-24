from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.utils.translation import gettext_lazy as _

from src.apps.core.models import (
    AvailabilityMixin,
    LocationModel,
    OrganizationMixin,
    SoftDeleteModel,
)


class Service(SoftDeleteModel, OrganizationMixin, LocationModel, AvailabilityMixin):
    """Individual service offered by organizations."""

    class ServiceAvailabilityType(models.TextChoices):
        ALWAYS = 'A', _('Always Available')
        SCHEDULED = 'S', _('Scheduled Times')
        ON_DEMAND = 'O', _('On Demand')
        APPOINTMENT = 'P', _('Appointment Only')

    name = models.CharField(max_length=255)
    sub_category = models.ForeignKey(
        'ServiceSubCategory',
        on_delete=models.CASCADE,
        related_name='services',
    )
    organization = models.ForeignKey(
        'organizations.Organization',
        on_delete=models.CASCADE,
        related_name='services',
    )
    description = models.TextField()
    price_min = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        validators=[MinValueValidator(0)],
    )
    price_max = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        validators=[MinValueValidator(0)],
    )
    accepted_currency = models.ForeignKey(
        'organizations.CountryAcceptedCurrency',
        on_delete=models.PROTECT,
        related_name='services',
        null=True,
        blank=True,
    )
    show_location_on_listing = models.BooleanField(
        default=True,
        help_text='When false, service address is hidden from public catalog.',
    )
    accepted_location_types = models.JSONField(
        default=list,
        blank=True,
        help_text='Venue types for this service (O/H/V/B). Empty inherits organization defaults.',
    )
    is_active = models.BooleanField(default=True)
    featured = models.BooleanField(default=False)
    requires_verification = models.BooleanField(default=True)

    availability_type = models.CharField(
        max_length=1,
        choices=ServiceAvailabilityType.choices,
        default=ServiceAvailabilityType.APPOINTMENT,
    )

    class Meta:
        db_table = 'services'
        unique_together = [['name', 'organization']]
        ordering = ['-featured', 'name']
        indexes = [
            models.Index(fields=['organization']),
            models.Index(fields=['sub_category']),
            models.Index(fields=['name']),
            models.Index(fields=['is_active']),
            models.Index(fields=['featured']),
            models.Index(fields=['price_min']),
            models.Index(fields=['availability_type']),
            models.Index(fields=['deleted_at']),
            models.Index(fields=['available_days']),
        ]

    _AVAILABILITY_CSS = {
        ServiceAvailabilityType.ALWAYS.value: 'success',
        ServiceAvailabilityType.SCHEDULED.value: 'primary',
        ServiceAvailabilityType.ON_DEMAND.value: 'info',
        ServiceAvailabilityType.APPOINTMENT.value: 'warning',
    }

    def get_availability_type_css(self):
        return self._AVAILABILITY_CSS.get(self.availability_type, 'default')

    def __str__(self):
        return f'{self.name} - {self.organization.name}'


class ServiceVariantModel(SoftDeleteModel):
    """Service variant with duration and pricing."""

    class ServiceVariant(models.TextChoices):
        FIXED = 'F', _('Fixed Duration')
        FLEXIBLE = 'X', _('Flexible Duration')

    service = models.ForeignKey(
        Service,
        on_delete=models.CASCADE,
        related_name='variants',
    )
    name = models.CharField(max_length=255)
    duration_minutes = models.PositiveIntegerField(
        validators=[MinValueValidator(15), MaxValueValidator(480)],
    )
    duration_type = models.CharField(
        max_length=1,
        choices=ServiceVariant.choices,
        default=ServiceVariant.FIXED,
    )
    price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        validators=[MinValueValidator(0)],
    )
    is_popular = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = 'service_variants'
        ordering = ['is_popular', 'duration_minutes']
        indexes = [
            models.Index(fields=['service']),
            models.Index(fields=['duration_minutes']),
            models.Index(fields=['price']),
            models.Index(fields=['is_popular']),
            models.Index(fields=['is_active']),
        ]

    _DURATION_TYPE_CSS = {
        ServiceVariant.FIXED.value: 'secondary',
        ServiceVariant.FLEXIBLE.value: 'info',
    }

    def get_duration_type_css(self):
        return self._DURATION_TYPE_CSS.get(self.duration_type, 'default')

    def __str__(self):
        return f'{self.name} ({self.duration_minutes}min) - ${self.price}'
