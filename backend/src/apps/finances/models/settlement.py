import uuid
from decimal import Decimal

from django.conf import settings
from django.core.validators import MinValueValidator
from django.db import models
from django.utils.translation import gettext_lazy as _

from src.apps.core.models import SoftDeleteModel


class SettlementAccount(SoftDeleteModel):
    """Business payout destination tied to a PaymentMethod rail."""

    organization = models.ForeignKey(
        'organizations.Organization',
        on_delete=models.CASCADE,
        related_name='settlement_accounts',
    )
    method = models.ForeignKey(
        'payments.PaymentMethod',
        on_delete=models.PROTECT,
        related_name='settlement_accounts',
    )
    label = models.CharField(max_length=128, blank=True)
    is_default = models.BooleanField(default=False)

    account_identifier = models.CharField(
        max_length=255,
        help_text='Primary rail id: IBAN, account number, phone, email, …',
    )
    account_name = models.CharField(
        max_length=255,
        blank=True,
        help_text='Account holder / destination name.',
    )
    details = models.JSONField(
        default=dict,
        blank=True,
        help_text='Extra destination fields (bic_swift, bank_name, …).',
    )

    class Meta:
        db_table = 'settlement_accounts'
        ordering = ['-is_default', '-created_at']
        indexes = [
            models.Index(fields=['organization']),
        ]

    def __str__(self):
        return f'{self.organization_id} {self.method_id}'


class SettlementSettings(models.Model):
    """Per-organization settlement periodicity and minimum."""

    class Periodicity(models.TextChoices):
        WEEKLY = 'W', _('Weekly')
        BIWEEKLY = 'B', _('Biweekly')
        MONTHLY = 'M', _('Monthly')
        MANUAL = 'N', _('Manual only')

    organization = models.OneToOneField(
        'organizations.Organization',
        on_delete=models.CASCADE,
        related_name='settlement_settings',
    )
    periodicity = models.CharField(
        max_length=1,
        choices=Periodicity.choices,
        default=Periodicity.MANUAL,
    )
    minimum_amount = models.DecimalField(
        max_digits=14,
        decimal_places=2,
        default=Decimal('10.00'),
        validators=[MinValueValidator(Decimal('0.01'))],
    )
    currency = models.ForeignKey(
        'finances.Currency',
        on_delete=models.PROTECT,
        related_name='settlement_settings',
    )
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'settlement_settings'

    def __str__(self):
        return f'{self.organization_id} settlement settings'


class SettlementRequest(models.Model):
    """Business settlement request; staff confirms manually when no payout integration."""

    class Status(models.TextChoices):
        REQUESTED = 'R', _('Requested')
        PROCESSING = 'P', _('Processing')
        COMPLETED = 'C', _('Completed')
        REJECTED = 'X', _('Rejected')

    _STATUS_CSS = {
        Status.REQUESTED.value: 'warning',
        Status.PROCESSING.value: 'info',
        Status.COMPLETED.value: 'success',
        Status.REJECTED.value: 'danger',
    }

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    organization = models.ForeignKey(
        'organizations.Organization',
        on_delete=models.CASCADE,
        related_name='settlement_requests',
    )
    amount = models.DecimalField(
        max_digits=14,
        decimal_places=2,
        validators=[MinValueValidator(Decimal('0.01'))],
    )
    currency = models.ForeignKey(
        'finances.Currency',
        on_delete=models.PROTECT,
        related_name='settlement_requests',
    )
    status = models.CharField(
        max_length=1,
        choices=Status.choices,
        default=Status.REQUESTED,
    )
    settlement_account = models.ForeignKey(
        SettlementAccount,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='requests',
    )
    method_code = models.CharField(
        max_length=64,
        help_text='PaymentMethod.code snapshot at request time.',
    )
    destination_snapshot = models.JSONField(default=dict, blank=True)

    requested_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='settlement_requests_created',
    )
    staff_note = models.TextField(blank=True)
    confirmation_image = models.ImageField(
        upload_to='settlement_confirmations/',
        null=True,
        blank=True,
        help_text='Staff-only proof of payout; never exposed to businesses.',
    )
    processed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='settlement_requests_processed',
    )
    processed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'settlement_requests'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['organization']),
            models.Index(fields=['status']),
            models.Index(fields=['created_at']),
        ]

    def get_status_css(self):
        return self._STATUS_CSS.get(self.status, 'default')

    def __str__(self):
        return f'Settlement {self.amount} {self.currency_id} ({self.status})'
