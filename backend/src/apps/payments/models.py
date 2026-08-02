import uuid

from django.conf import settings
from django.core.validators import MinValueValidator
from django.db import models
from django.utils.translation import gettext_lazy as _

from src.apps.core.models import SoftDeleteModel, AuditedModelMixin
from src.apps.payments.catalog import PaymentConnector, PaymentMethod  # noqa: F401


class PaymentProvider(SoftDeleteModel):
    """Registered payment integration (per gateway / channel)."""

    class ProviderType(models.TextChoices):
        MOMO = 'M', _('Mobile money')
        CARD = 'C', _('Card')
        BANK = 'B', _('Bank')
        WALLET = 'W', _('Wallet')
        OTHER = 'O', _('Other')

    code = models.SlugField(max_length=64, unique=True)
    provider_type = models.CharField(
        max_length=1,
        choices=ProviderType.choices,
        default=ProviderType.OTHER,
    )
    display_name = models.CharField(max_length=128, blank=True)
    is_active = models.BooleanField(default=True)
    config = models.JSONField(default=dict, blank=True)

    supported_countries = models.ManyToManyField(
        'organizations.Country',
        related_name='payment_providers',
        blank=True,
    )
    supported_currencies = models.ManyToManyField(
        'finances.Currency',
        related_name='payment_providers',
        blank=True,
    )

    class Meta:
        db_table = 'payment_providers'
        ordering = ['code']

    def __str__(self):
        return f'{self.code} ({self.get_provider_type_display()})'


class PaymentTransaction(AuditedModelMixin, models.Model):
    """Append-only payment activity for a booking (payments, refunds, webhooks)."""

    class TransactionKind(models.TextChoices):
        AUTHORIZATION = 'A', _('Authorization')
        PAYMENT = 'P', _('Payment')
        REFUND = 'R', _('Refund')
        PARTIAL_REFUND = 'V', _('Partial refund')

    class TransactionStatus(models.TextChoices):
        PENDING = 'N', _('Pending')
        PROCESSING = 'G', _('Processing')
        SUCCEEDED = 'S', _('Succeeded')
        FAILED = 'F', _('Failed')
        CANCELLED = 'X', _('Cancelled')

    class Purpose(models.TextChoices):
        BOOKING = 'B', _('Booking payment')
        WALLET_TOP_UP = 'W', _('Store credit top-up')

    _KIND_CSS = {
        TransactionKind.AUTHORIZATION.value: 'info',
        TransactionKind.PAYMENT.value: 'primary',
        TransactionKind.REFUND.value: 'warning',
        TransactionKind.PARTIAL_REFUND.value: 'warning',
    }
    _STATUS_CSS = {
        TransactionStatus.PENDING.value: 'warning',
        TransactionStatus.PROCESSING.value: 'info',
        TransactionStatus.SUCCEEDED.value: 'success',
        TransactionStatus.FAILED.value: 'danger',
        TransactionStatus.CANCELLED.value: 'secondary',
    }

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    booking = models.ForeignKey(
        'bookings.Booking',
        on_delete=models.CASCADE,
        related_name='payment_transactions',
        null=True,
        blank=True,
    )
    purpose = models.CharField(
        max_length=1,
        choices=Purpose.choices,
        default=Purpose.BOOKING,
        db_index=True,
    )
    payment_provider = models.ForeignKey(
        PaymentProvider,
        on_delete=models.PROTECT,
        related_name='transactions',
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='payment_transactions_as_payer',
        help_text='Customer (payer) when applicable.',
    )
    initiated_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='payment_transactions_initiated',
        help_text='Staff user for refunds/captures initiated by org.',
    )

    amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        validators=[MinValueValidator(0)],
    )
    currency = models.ForeignKey(
        'finances.Currency',
        on_delete=models.PROTECT,
        related_name='payment_transactions',
    )
    kind = models.CharField(
        max_length=1,
        choices=TransactionKind.choices,
    )
    status = models.CharField(
        max_length=1,
        choices=TransactionStatus.choices,
        default=TransactionStatus.PENDING,
    )

    provider_reference = models.CharField(max_length=255, blank=True)
    idempotency_key = models.CharField(max_length=128, blank=True, db_index=True)
    client_reference = models.CharField(max_length=128, blank=True)

    provider_response_code = models.CharField(max_length=64, blank=True)
    provider_response_body = models.JSONField(null=True, blank=True)
    provider_request_payload = models.JSONField(null=True, blank=True)

    webhook_received_at = models.DateTimeField(null=True, blank=True)
    webhook_payload = models.JSONField(null=True, blank=True)
    webhook_signature_valid = models.BooleanField(null=True, blank=True)

    payer_account_masked = models.CharField(max_length=64, blank=True)
    payee_account_masked = models.CharField(max_length=64, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'payment_transactions'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['booking']),
            models.Index(fields=['payment_provider']),
            models.Index(fields=['status']),
            models.Index(fields=['kind']),
            models.Index(fields=['created_at']),
        ]
        constraints = [
            models.UniqueConstraint(
                fields=['payment_provider', 'idempotency_key'],
                condition=models.Q(idempotency_key__gt=''),
                name='unique_provider_idempotency_when_set',
            ),
        ]

    def __str__(self):
        return f'{self.kind} {self.amount} {self.currency_id} ({self.status})'

    def get_kind_css(self):
        return self._KIND_CSS.get(self.kind, 'default')

    def get_status_css(self):
        return self._STATUS_CSS.get(self.status, 'default')


class RefundWallet(models.Model):
    """Per-user, per-currency store credit from cancellation refunds."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='refund_wallets',
    )
    currency = models.ForeignKey(
        'finances.Currency',
        on_delete=models.PROTECT,
        related_name='refund_wallets',
    )
    balance = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0,
        validators=[MinValueValidator(0)],
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'refund_wallets'
        ordering = ['currency__code']
        constraints = [
            models.UniqueConstraint(
                fields=['user', 'currency'],
                name='unique_refund_wallet_user_currency',
            ),
        ]

    def __str__(self):
        return f'{self.user_id} {self.balance} {self.currency_id}'


class RefundWalletLedger(models.Model):
    """Append-only ledger for refund wallet credits and debits."""

    class Kind(models.TextChoices):
        CANCELLATION_CREDIT = 'C', _('Cancellation credit')
        APPLIED_TO_BOOKING = 'A', _('Applied to booking')
        TOP_UP = 'T', _('Store credit top-up')
        MANUAL = 'M', _('Manual adjustment')

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    wallet = models.ForeignKey(
        RefundWallet,
        on_delete=models.CASCADE,
        related_name='ledger_entries',
    )
    booking = models.ForeignKey(
        'bookings.Booking',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='refund_wallet_ledger',
    )
    kind = models.CharField(max_length=1, choices=Kind.choices)
    amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        validators=[MinValueValidator(0)],
        help_text='Absolute amount; sign is implied by kind (credit vs debit).',
    )
    balance_after = models.DecimalField(max_digits=12, decimal_places=2)
    idempotency_key = models.CharField(max_length=128, blank=True, db_index=True)
    note = models.CharField(max_length=255, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'refund_wallet_ledger'
        ordering = ['-created_at']
        constraints = [
            models.UniqueConstraint(
                fields=['idempotency_key'],
                condition=models.Q(idempotency_key__gt=''),
                name='unique_refund_wallet_ledger_idempotency',
            ),
        ]

    def __str__(self):
        return f'{self.kind} {self.amount} ({self.wallet_id})'
