from django.db import models
from django.core.validators import MinValueValidator, MaxValueValidator
from src.apps.core.models import SoftDeleteModel, OrganizationMixin, LocationModel, AvailabilityMixin


class Service(SoftDeleteModel, OrganizationMixin, LocationModel, AvailabilityMixin):
    """Individual service offered by organizations."""

    class ServiceAvailabilityType(models.TextChoices):
        ALWAYS = 'A', 'Always Available'
        SCHEDULED = 'S', 'Scheduled Times'
        ON_DEMAND = 'O', 'On Demand'
        APPOINTMENT = 'P', 'Appointment Only'

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
    currency = models.CharField(max_length=3, default='USD')
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

    def __str__(self):
        return f'{self.name} - {self.organization.name}'


class ServiceVariantModel(SoftDeleteModel):
    """Service variant with duration and pricing."""

    class ServiceVariant(models.TextChoices):
        FIXED = 'F', 'Fixed Duration'
        FLEXIBLE = 'X', 'Flexible Duration'

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

    def __str__(self):
        return f'{self.name} ({self.duration_minutes}min) - ${self.price}'
