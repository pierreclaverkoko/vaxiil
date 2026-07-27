"""FX conversion helpers (USD → local currency)."""

from __future__ import annotations

from decimal import ROUND_HALF_UP, Decimal

from django.utils import timezone
from django.utils.translation import gettext as _
from rest_framework.exceptions import ValidationError

from src.apps.finances.models import Currency, CurrencyFxRate

TWOPLACES = Decimal('0.01')


def usd_to_currency(
    amount_usd: Decimal,
    to_currency: Currency,
    *,
    at=None,
) -> Decimal:
    """
    Convert a USD amount into ``to_currency`` using the latest staff FX rate.

    If ``to_currency`` is already USD, returns the amount quantized to 2dp.
    Raises ValidationError when no rate is configured.
    """
    amount = Decimal(amount_usd).quantize(TWOPLACES, rounding=ROUND_HALF_UP)
    if amount < 0:
        raise ValidationError({'amount': _('Amount must be non-negative.')})
    if to_currency.code.upper() == 'USD':
        return amount

    usd = Currency.objects.filter(code='USD', is_active=True).first()
    if usd is None:
        raise ValidationError({'currency': _('USD currency is not configured.')})

    when = at or timezone.now()
    rate_row = (
        CurrencyFxRate.objects.filter(
            from_currency=usd,
            to_currency=to_currency,
            effective_at__lte=when,
        )
        .order_by('-effective_at', '-created_at')
        .first()
    )
    if rate_row is None:
        raise ValidationError(
            {
                'fx_rate': _(
                    'No exchange rate from USD to %(code)s. Contact support.'
                )
                % {'code': to_currency.code}
            }
        )
    return (amount * Decimal(rate_row.rate)).quantize(
        TWOPLACES, rounding=ROUND_HALF_UP
    )
