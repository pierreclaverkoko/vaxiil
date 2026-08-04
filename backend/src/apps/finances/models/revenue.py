import uuid
from decimal import Decimal

from django.conf import settings
from django.db import models
from django.utils.translation import gettext_lazy as _


class OrganizationRevenueWallet(models.Model):
    """Per-organization, per-currency revenue balance available for settlement."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    organization = models.ForeignKey(
        'organizations.Organization',
        on_delete=models.CASCADE,
        related_name='revenue_wallets',
    )
    currency = models.ForeignKey(
        'finances.Currency',
        on_delete=models.PROTECT,
        related_name='org_revenue_wallets',
    )
    balance = models.DecimalField(max_digits=14, decimal_places=2, default=Decimal('0'))
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'organization_revenue_wallets'
        ordering = ['currency__code']
        constraints = [
            models.UniqueConstraint(
                fields=['organization', 'currency'],
                name='unique_org_revenue_wallet_currency',
            ),
        ]

    def __str__(self):
        return f'{self.organization_id} {self.balance} {self.currency_id}'


class OrganizationRevenueLedger(models.Model):
    """Append-only ledger for organization revenue credits and debits."""

    class Kind(models.TextChoices):
        BOOKING_CREDIT = 'B', _('Booking credit')
        PLATFORM_FEE = 'P', _('Platform fee')
        ANNUAL_SUBSCRIPTION = 'A', _('Annual subscription')
        SETTLEMENT_DEBIT = 'S', _('Settlement')
        STAFF_ADJUSTMENT = 'T', _('Staff adjustment')
        MANUAL_SETTLEMENT = 'M', _('Manual settlement')
        CANCELLATION_DEBIT = 'C', _('Cancellation debit')
        CANCELLATION_PENALTY = 'L', _('Cancellation penalty')

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    wallet = models.ForeignKey(
        OrganizationRevenueWallet,
        on_delete=models.CASCADE,
        related_name='ledger_entries',
    )
    kind = models.CharField(max_length=1, choices=Kind.choices)
    amount = models.DecimalField(
        max_digits=14,
        decimal_places=2,
        help_text='Signed amount: positive credit, negative debit.',
    )
    balance_after = models.DecimalField(max_digits=14, decimal_places=2)
    reason = models.CharField(max_length=512, blank=True)
    booking = models.ForeignKey(
        'bookings.Booking',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='org_revenue_ledger',
    )
    settlement_request = models.ForeignKey(
        'finances.SettlementRequest',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='ledger_entries',
    )
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='org_revenue_ledger_created',
    )
    idempotency_key = models.CharField(max_length=128, blank=True, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'organization_revenue_ledger'
        ordering = ['-created_at']
        constraints = [
            models.UniqueConstraint(
                fields=['idempotency_key'],
                condition=models.Q(idempotency_key__gt=''),
                name='unique_org_revenue_ledger_idempotency',
            ),
        ]

    def __str__(self):
        return f'{self.kind} {self.amount} ({self.wallet_id})'
