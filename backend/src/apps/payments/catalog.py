"""Shared payment rail catalog (connectors + methods) for collect/refund/settlement."""

from __future__ import annotations

from django.contrib.postgres.fields import ArrayField
from django.db import models
from django.utils.translation import gettext_lazy as _

from src.apps.core.models import SoftDeleteModel


class PaymentConnector(SoftDeleteModel):
    """Aggregator / gateway / manual executor that owns PaymentMethod rails."""

    class ConnectorType(models.TextChoices):
        AGGREGATOR = 'A', _('Aggregator')
        DIRECT = 'D', _('Direct')
        GATEWAY = 'G', _('Gateway')
        MANUAL = 'M', _('Manual')

    _TYPE_CSS = {
        ConnectorType.AGGREGATOR.value: 'primary',
        ConnectorType.DIRECT.value: 'info',
        ConnectorType.GATEWAY.value: 'secondary',
        ConnectorType.MANUAL.value: 'warning',
    }

    code = models.SlugField(max_length=64, unique=True)
    name = models.CharField(max_length=128)
    connector_type = models.CharField(
        max_length=1,
        choices=ConnectorType.choices,
        default=ConnectorType.MANUAL,
    )
    adapter_key = models.SlugField(
        max_length=64,
        help_text='Execution registry key (often same as code).',
    )
    configuration = models.JSONField(default=dict, blank=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = 'payment_connectors'
        ordering = ['code']

    def get_connector_type_css(self):
        return self._TYPE_CSS.get(self.connector_type, 'default')

    def __str__(self):
        return f'{self.code} ({self.get_connector_type_display()})'


class PaymentMethod(SoftDeleteModel):
    """Country-scoped rail (bank, MoMo, fintech, crypto) under a PaymentConnector."""

    class MethodType(models.TextChoices):
        BANK = 'B', _('Bank')
        MOBILE_MONEY = 'M', _('Mobile money')
        FINTECH = 'F', _('Fintech')
        CRYPTO = 'C', _('Crypto')
        OTHER = 'O', _('Other')

    class Operation(models.TextChoices):
        SETTLEMENT = 'settlement', _('Settlement')
        COLLECT = 'collect', _('Collect')
        REFUND = 'refund', _('Refund')
        WALLET_FUND = 'wallet_fund', _('Wallet fund')
        PAYOUT = 'payout', _('Payout')

    _TYPE_CSS = {
        MethodType.BANK.value: 'primary',
        MethodType.MOBILE_MONEY.value: 'info',
        MethodType.FINTECH.value: 'success',
        MethodType.CRYPTO.value: 'warning',
        MethodType.OTHER.value: 'secondary',
    }

    connector = models.ForeignKey(
        PaymentConnector,
        on_delete=models.PROTECT,
        related_name='methods',
    )
    code = models.SlugField(max_length=64, unique=True)
    name = models.CharField(max_length=200)
    logo = models.ImageField(
        upload_to='payment_methods/logos/',
        blank=True,
        null=True,
    )
    method_type = models.CharField(
        max_length=1,
        choices=MethodType.choices,
        default=MethodType.OTHER,
    )
    country = models.ForeignKey(
        'organizations.Country',
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name='payment_methods',
        help_text='Null = globally available (e.g. SWIFT IBAN).',
    )
    currency = models.ForeignKey(
        'finances.Currency',
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name='payment_methods',
    )
    account_regex = models.CharField(max_length=255, blank=True)
    config = models.JSONField(
        default=dict,
        blank=True,
        help_text='e.g. {"destination_fields": ["iban", "bic_swift", "account_holder_name"]}',
    )
    supported_operations = ArrayField(
        models.CharField(max_length=32),
        default=list,
        blank=True,
        help_text='Operations this rail supports: settlement, collect, refund, wallet_fund, payout.',
    )
    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = 'payment_methods'
        ordering = ['country', 'method_type', 'name']
        indexes = [
            models.Index(fields=['code']),
            models.Index(fields=['method_type']),
            models.Index(fields=['is_active']),
        ]

    def get_method_type_css(self):
        return self._TYPE_CSS.get(self.method_type, 'default')

    def supports_operation(self, operation: str) -> bool:
        return operation in (self.supported_operations or [])

    def __str__(self):
        return f'{self.code} ({self.name})'
