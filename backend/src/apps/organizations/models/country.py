from django.db import models
from django.db.models import Q, UniqueConstraint
from django.core.exceptions import ValidationError

from src.apps.core.models import SoftDeleteModel


class Country(SoftDeleteModel):
    """ISO country reference."""

    iso_code2 = models.CharField(max_length=2, unique=True)
    iso_code3 = models.CharField(max_length=3, unique=True)
    name = models.CharField(max_length=128)
    flag = models.URLField(blank=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = 'countries'
        ordering = ['name']
        indexes = [
            models.Index(fields=['iso_code2']),
            models.Index(fields=['iso_code3']),
            models.Index(fields=['is_active']),
        ]

    def __str__(self):
        return self.name


class CountryAcceptedCurrency(SoftDeleteModel):
    """Which currencies are accepted in a country; used for Service/Booking pricing."""

    country = models.ForeignKey(
        Country,
        on_delete=models.CASCADE,
        related_name='accepted_currencies',
    )
    currency = models.ForeignKey(
        'finances.Currency',
        on_delete=models.PROTECT,
        related_name='country_acceptances',
    )
    is_active = models.BooleanField(default=True)
    is_default = models.BooleanField(default=False)

    class Meta:
        db_table = 'country_accepted_currencies'
        constraints = [
            UniqueConstraint(
                fields=['country', 'currency'],
                condition=Q(deleted_at__isnull=True),
                name='unique_country_currency_active',
            ),
        ]
        indexes = [
            models.Index(fields=['country']),
            models.Index(fields=['currency']),
            models.Index(fields=['is_active']),
            models.Index(fields=['is_default']),
        ]

    def __str__(self):
        return f'{self.country.iso_code2} — {self.currency.code}'

    def clean(self):
        super().clean()
        if self.is_default and self.country_id:
            qs = CountryAcceptedCurrency.objects.filter(
                country_id=self.country_id,
                is_default=True,
                deleted_at__isnull=True,
            ).exclude(pk=self.pk)
            if qs.exists():
                raise ValidationError(
                    {'is_default': 'Only one default currency per country is allowed.'}
                )
