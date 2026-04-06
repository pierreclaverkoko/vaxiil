from django.core.validators import MinValueValidator, MaxValueValidator
from django.db import models


class Currency(models.Model):
    """ISO 4217 currency reference (used via CountryAcceptedCurrency for pricing)."""

    code = models.CharField(max_length=3, unique=True)
    symbol = models.CharField(max_length=16)
    name = models.CharField(max_length=128)
    numeric_code = models.CharField(max_length=3)
    minor_units = models.PositiveSmallIntegerField(
        default=2,
        validators=[MinValueValidator(0), MaxValueValidator(4)],
    )
    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = 'currencies'
        ordering = ['code']
        verbose_name_plural = 'currencies'

    def __str__(self):
        return f'{self.code} ({self.name})'
