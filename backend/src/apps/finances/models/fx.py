import uuid
from decimal import Decimal

from django.core.validators import MinValueValidator
from django.db import models


class CurrencyFxRate(models.Model):
    """Staff-managed FX rate from USD into a local currency (latest effective wins)."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    from_currency = models.ForeignKey(
        'finances.Currency',
        on_delete=models.PROTECT,
        related_name='fx_rates_from',
    )
    to_currency = models.ForeignKey(
        'finances.Currency',
        on_delete=models.PROTECT,
        related_name='fx_rates_to',
    )
    rate = models.DecimalField(
        max_digits=18,
        decimal_places=8,
        validators=[MinValueValidator(Decimal('0.00000001'))],
        help_text='Multiply USD amount by this rate to get to_currency.',
    )
    effective_at = models.DateTimeField()
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.ForeignKey(
        'users.User',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='fx_rates_created',
    )

    class Meta:
        db_table = 'currency_fx_rates'
        ordering = ['-effective_at', '-created_at']
        indexes = [
            models.Index(fields=['from_currency', 'to_currency', '-effective_at']),
        ]

    def __str__(self):
        return (
            f'{self.from_currency_id}->{self.to_currency_id} '
            f'{self.rate} @ {self.effective_at}'
        )
