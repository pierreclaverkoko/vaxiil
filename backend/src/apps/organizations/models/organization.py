import uuid
from django.db import models
from src.apps.core.models import SoftDeleteModel


class OrganizationTypeModel(SoftDeleteModel):
    """Dynamic organization type model."""

    class Kind(models.TextChoices):
        HOTEL = 'H', 'Hotel'
        SPA = 'P', 'Spa'
        INDEPENDENT = 'I', 'Independent Practitioner'
        CLINIC = 'C', 'Wellness Clinic'
        SALON = 'L', 'Beauty Salon'

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


class Organization(SoftDeleteModel):
    """Organization model representing businesses offering wellness services."""

    class VerificationStatus(models.TextChoices):
        PENDING = 'P', 'Pending Verification'
        VERIFIED = 'V', 'Verified'
        REJECTED = 'R', 'Rejected'
        SUSPENDED = 'S', 'Suspended'

    name = models.CharField(max_length=255)
    country = models.ForeignKey(
        'organizations.Country',
        on_delete=models.PROTECT,
        related_name='organizations',
        null=True,
        blank=True,
    )
    default_currency = models.ForeignKey(
        'organizations.CountryAcceptedCurrency',
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name='organizations_defaulting',
        help_text='Default CountryAcceptedCurrency for services/bookings when unspecified.',
    )
    type = models.ForeignKey(
        OrganizationTypeModel,
        on_delete=models.PROTECT,
        related_name='organizations',
    )
    description = models.TextField(blank=True)
    phone = models.CharField(max_length=20, blank=True)
    email = models.EmailField(unique=True)
    website = models.URLField(blank=True)
    logo = models.ImageField(
        upload_to='organization_logos/',
        blank=True,
        null=True,
        help_text='Square company logo (1:1). Required when creating a new organization via API.',
    )

    verification_status = models.CharField(
        max_length=1,
        choices=VerificationStatus.choices,
        default=VerificationStatus.PENDING,
    )
    business_license_number = models.CharField(max_length=100, blank=True)
    tax_id = models.CharField(max_length=50, blank=True)

    business_license_document = models.FileField(
        upload_to='verification_documents/',
        blank=True,
        null=True,
    )
    id_document = models.FileField(
        upload_to='verification_documents/',
        blank=True,
        null=True,
    )

    verified_at = models.DateTimeField(null=True, blank=True)
    verified_by = models.ForeignKey(
        'users.User',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='verified_organizations',
    )
    rejection_reason = models.TextField(blank=True)

    kyb_submitted_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text='Set when KYB documents are submitted for staff review.',
    )

    is_active = models.BooleanField(default=True)
    accepts_bookings = models.BooleanField(default=True)
    requires_prepayment = models.BooleanField(default=True)

    class Meta:
        db_table = 'organizations'
        indexes = [
            models.Index(fields=['name']),
            models.Index(fields=['type']),
            models.Index(fields=['country']),
            models.Index(fields=['verification_status']),
            models.Index(fields=['email']),
            models.Index(fields=['deleted_at']),
        ]
        constraints = [
            models.UniqueConstraint(
                fields=['email'],
                condition=models.Q(deleted_at__isnull=True),
                name='unique_organization_email',
            ),
        ]

    def __str__(self):
        return self.name

    def primary_address(self):
        """First primary, else first active address."""
        return (
            self.addresses.filter(deleted_at__isnull=True)
            .order_by('-is_primary', 'created_at')
            .first()
        )

    @property
    def is_verified(self):
        return self.verification_status == self.VerificationStatus.VERIFIED

    _VERIFICATION_CSS = {
        VerificationStatus.PENDING.value: 'warning',
        VerificationStatus.VERIFIED.value: 'success',
        VerificationStatus.REJECTED.value: 'danger',
        VerificationStatus.SUSPENDED.value: 'secondary',
    }

    def get_verification_status_css(self):
        return self._VERIFICATION_CSS.get(self.verification_status, 'default')


class OrganizationSettings(SoftDeleteModel):
    """Organization-specific settings."""

    organization = models.OneToOneField(
        Organization,
        on_delete=models.CASCADE,
        related_name='settings',
    )

    minimum_booking_hours_notice = models.PositiveIntegerField(default=2)
    maximum_booking_days_ahead = models.PositiveIntegerField(default=30)
    cancellation_hours_notice = models.PositiveIntegerField(default=24)

    commission_rate = models.DecimalField(max_digits=5, decimal_places=2, default=0.15)
    payout_delay_days = models.PositiveIntegerField(default=7)

    class Meta:
        db_table = 'organization_settings'
        indexes = [
            models.Index(fields=['organization']),
        ]

    def __str__(self):
        return f'{self.organization.name} Settings'


class OrganizationTypeSubCategory(SoftDeleteModel):
    """Link organization types to default subcategories."""

    organization_type = models.ForeignKey(
        OrganizationTypeModel,
        on_delete=models.CASCADE,
        related_name='default_subcategories',
    )
    sub_category = models.ForeignKey(
        'services.ServiceSubCategory',
        on_delete=models.CASCADE,
        related_name='organization_types',
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
        return f'{self.organization_type.display_name} - {self.sub_category.name}'
