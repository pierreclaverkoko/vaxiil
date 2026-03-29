import uuid
from django.db import models
from src.apps.core.models import SoftDeleteModel, LocationModel


class OrganizationType(models.TextChoices):
    """Organization type choices."""
    HOTEL = 'HOTEL', 'Hotel'
    SPA = 'SPA', 'Spa'
    INDEPENDENT = 'INDEPENDENT', 'Independent Practitioner'
    CLINIC = 'CLINIC', 'Wellness Clinic'
    SALON = 'SALON', 'Beauty Salon'


class VerificationStatus(models.TextChoices):
    """Verification status choices."""
    PENDING = 'PENDING', 'Pending Verification'
    VERIFIED = 'VERIFIED', 'Verified'
    REJECTED = 'REJECTED', 'Rejected'
    SUSPENDED = 'SUSPENDED', 'Suspended'


class OrganizationTypeModel(SoftDeleteModel):
    """Dynamic organization type model."""
    
    name = models.CharField(max_length=100, unique=True)
    display_name = models.CharField(max_length=100)
    description = models.TextField(blank=True)
    icon = models.CharField(max_length=50, blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'organization_types'
        ordering = ['display_name']
        indexes = [
            models.Index(fields=['name']),
            models.Index(fields=['is_active']),
            models.Index(fields=['display_name']),
        ]
    
    def __str__(self):
        return self.display_name


class Organization(SoftDeleteModel, LocationModel):
    """Organization model representing businesses offering wellness services."""
    
    name = models.CharField(max_length=255)
    type = models.ForeignKey(
        OrganizationTypeModel,
        on_delete=models.PROTECT,
        related_name='organizations'
    )
    description = models.TextField(blank=True)
    phone = models.CharField(max_length=20, blank=True)
    email = models.EmailField(unique=True)
    website = models.URLField(blank=True)
    
    # KYB Fields
    verification_status = models.CharField(
        max_length=20,
        choices=VerificationStatus.choices,
        default=VerificationStatus.PENDING
    )
    business_license_number = models.CharField(max_length=100, blank=True)
    tax_id = models.CharField(max_length=50, blank=True)
    
    # Verification documents
    business_license_document = models.FileField(
        upload_to='verification_documents/',
        blank=True,
        null=True
    )
    id_document = models.FileField(
        upload_to='verification_documents/',
        blank=True,
        null=True
    )
    
    # Verification metadata
    verified_at = models.DateTimeField(null=True, blank=True)
    verified_by = models.ForeignKey(
        'users.User',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='verified_organizations'
    )
    rejection_reason = models.TextField(blank=True)
    
    # Business settings
    is_active = models.BooleanField(default=True)
    accepts_bookings = models.BooleanField(default=True)
    requires_prepayment = models.BooleanField(default=True)
    
    class Meta:
        db_table = 'organizations'
        indexes = [
            models.Index(fields=['name']),
            models.Index(fields=['type']),
            models.Index(fields=['verification_status']),
            models.Index(fields=['email']),
            models.Index(fields=['deleted_at']),
        ]
        constraints = [
            models.UniqueConstraint(
                fields=['email'],
                condition=models.Q(deleted_at__isnull=True),
                name='unique_organization_email'
            ),
        ]
    
    def __str__(self):
        return self.name
    
    @property
    def is_verified(self):
        """Check if organization is verified."""
        return self.verification_status == VerificationStatus.VERIFIED


class OrganizationSettings(SoftDeleteModel):
    """Organization-specific settings."""
    
    organization = models.OneToOneField(
        Organization,
        on_delete=models.CASCADE,
        related_name='settings'
    )
    
    # Booking settings
    minimum_booking_hours_notice = models.PositiveIntegerField(default=2)
    maximum_booking_days_ahead = models.PositiveIntegerField(default=30)
    cancellation_hours_notice = models.PositiveIntegerField(default=24)
    
    # Payment settings
    commission_rate = models.DecimalField(max_digits=5, decimal_places=2, default=0.15)
    payout_delay_days = models.PositiveIntegerField(default=7)
    
    class Meta:
        db_table = 'organization_settings'
        indexes = [
            models.Index(fields=['organization']),
        ]
    
    def __str__(self):
        return f"{self.organization.name} Settings"


class OrganizationTypeSubCategory(SoftDeleteModel):
    """Link organization types to default subcategories."""
    
    organization_type = models.ForeignKey(
        OrganizationTypeModel,
        on_delete=models.CASCADE,
        related_name='default_subcategories'
    )
    sub_category = models.ForeignKey(
        'services.ServiceSubCategory',
        on_delete=models.CASCADE,
        related_name='organization_types'
    )
    is_default = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        db_table = 'organization_type_subcategories'
        unique_together = [['organization_type', 'sub_category']]
        ordering = ['organization_type', 'sub_category']
        indexes = [
            models.Index(fields=['organization_type']),
            models.Index(fields=['sub_category']),
            models.Index(fields=['is_default']),
        ]
    
    def __str__(self):
        return f"{self.organization_type.display_name} - {self.sub_category.name}"
