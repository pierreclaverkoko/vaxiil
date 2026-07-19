import uuid
from decimal import Decimal

from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.utils.translation import gettext_lazy as _

from src.apps.core.models import SoftDeleteModel


class PlatformSettings(models.Model):
    """Singleton global platform fee configuration (staff-managed)."""

    id = models.PositiveSmallIntegerField(primary_key=True, default=1, editable=False)
    platform_fee_rate = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        default=Decimal('1.00'),
        validators=[MinValueValidator(0), MaxValueValidator(100)],
        help_text='Global platform fee percent (default 1.00 = 1%).',
    )
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'platform_settings'
        verbose_name_plural = 'platform settings'

    def save(self, *args, **kwargs):
        self.pk = 1
        super().save(*args, **kwargs)

    def delete(self, *args, **kwargs):
        pass

    @classmethod
    def get_solo(cls) -> 'PlatformSettings':
        obj, _ = cls.objects.get_or_create(pk=1)
        return obj

    def __str__(self):
        return f'PlatformSettings (fee={self.platform_fee_rate}%)'


class CategoryPlatformFee(SoftDeleteModel):
    """Optional platform fee override for a service category (staff-managed)."""

    category = models.OneToOneField(
        'services.ServiceCategory',
        on_delete=models.CASCADE,
        related_name='platform_fee',
    )
    rate = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        validators=[MinValueValidator(0), MaxValueValidator(100)],
        help_text='Platform fee percent for this category.',
    )

    class Meta:
        db_table = 'category_platform_fees'
        indexes = [
            models.Index(fields=['category']),
        ]

    def __str__(self):
        return f'{self.category.name}: {self.rate}%'


class PlatformFeeEntry(models.Model):
    """Append-only ledger of platform fees accrued or reversed."""

    class FeeSource(models.TextChoices):
        GLOBAL = 'G', _('Global')
        CATEGORY = 'C', _('Category')
        ORGANIZATION = 'O', _('Organization')

    class FeePayer(models.TextChoices):
        CLIENT = 'C', _('Client')
        BUSINESS = 'B', _('Business')

    class EntryStatus(models.TextChoices):
        ACCRUED = 'A', _('Accrued')
        REVERSED = 'R', _('Reversed')

    _SOURCE_CSS = {
        FeeSource.GLOBAL.value: 'secondary',
        FeeSource.CATEGORY.value: 'info',
        FeeSource.ORGANIZATION.value: 'primary',
    }
    _PAYER_CSS = {
        FeePayer.CLIENT.value: 'info',
        FeePayer.BUSINESS.value: 'warning',
    }
    _STATUS_CSS = {
        EntryStatus.ACCRUED.value: 'success',
        EntryStatus.REVERSED.value: 'danger',
    }

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    booking = models.ForeignKey(
        'bookings.Booking',
        on_delete=models.CASCADE,
        related_name='platform_fee_entries',
    )
    organization = models.ForeignKey(
        'organizations.Organization',
        on_delete=models.CASCADE,
        related_name='platform_fee_entries',
    )
    category = models.ForeignKey(
        'services.ServiceCategory',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='platform_fee_entries',
    )
    currency = models.ForeignKey(
        'finances.Currency',
        on_delete=models.PROTECT,
        related_name='platform_fee_entries',
    )
    amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        validators=[MinValueValidator(0)],
    )
    rate = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        validators=[MinValueValidator(0), MaxValueValidator(100)],
    )
    payer = models.CharField(max_length=1, choices=FeePayer.choices)
    source = models.CharField(max_length=1, choices=FeeSource.choices)
    status = models.CharField(
        max_length=1,
        choices=EntryStatus.choices,
        default=EntryStatus.ACCRUED,
    )
    payment_transaction = models.ForeignKey(
        'payments.PaymentTransaction',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='platform_fee_entries',
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'platform_fee_entries'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['organization']),
            models.Index(fields=['booking']),
            models.Index(fields=['status']),
            models.Index(fields=['created_at']),
            models.Index(fields=['payer']),
        ]

    def get_source_css(self):
        return self._SOURCE_CSS.get(self.source, 'default')

    def get_payer_css(self):
        return self._PAYER_CSS.get(self.payer, 'default')

    def get_status_css(self):
        return self._STATUS_CSS.get(self.status, 'default')

    def __str__(self):
        return f'Fee {self.amount} ({self.get_status_display()}) booking={self.booking_id}'
