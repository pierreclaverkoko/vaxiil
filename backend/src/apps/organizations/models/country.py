from django.db import models
from django.db.models import Q, UniqueConstraint
from django.core.exceptions import ValidationError

from src.apps.core.models import SoftDeleteModel


class Country(SoftDeleteModel):
    """Vaxiil country wrapper — GeoNames data lives on cities.Country (1:1)."""

    cities_country = models.OneToOneField(
        'cities.Country',
        on_delete=models.PROTECT,
        related_name='vaxiil_country',
    )
    flag = models.URLField(blank=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = 'countries'
        ordering = ['cities_country__name']
        indexes = [
            models.Index(fields=['is_active']),
        ]

    def __str__(self):
        return self.name

    @property
    def name(self) -> str:
        return getattr(self.cities_country, 'name', '') or ''

    @property
    def iso_code2(self) -> str:
        return getattr(self.cities_country, 'code', '') or ''

    @property
    def iso_code3(self) -> str:
        return getattr(self.cities_country, 'code3', '') or ''


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
