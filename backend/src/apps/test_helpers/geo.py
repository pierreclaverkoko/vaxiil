"""Shared reference data for tests (US + USD + default CAC)."""

from src.apps.finances.models import Currency
from src.apps.organizations.models import Country, CountryAcceptedCurrency, OrganizationAddress


def seed_us_country_and_currency():
    """Return (Country, CountryAcceptedCurrency) for United States / USD."""
    cur, _ = Currency.objects.get_or_create(
        code='USD',
        defaults={
            'symbol': '$',
            'name': 'US Dollar',
            'numeric_code': '840',
            'minor_units': 2,
            'is_active': True,
        },
    )
    ctry, _ = Country.objects.get_or_create(
        iso_code2='US',
        defaults={
            'iso_code3': 'USA',
            'name': 'United States',
            'flag': '',
            'is_active': True,
        },
    )
    cac, _ = CountryAcceptedCurrency.objects.get_or_create(
        country=ctry,
        currency=cur,
        defaults={'is_active': True, 'is_default': True},
    )
    return ctry, cac


def create_org_address(organization, country, **loc):
    """Primary address for an organization."""
    return OrganizationAddress.objects.create(
        organization=organization,
        address=loc.get('address', '1 Main St'),
        city=loc.get('city', 'NYC'),
        postal_code=loc.get('postal_code', '10001'),
        country_text=loc.get('country_text', ''),
        country=country,
        is_primary=True,
    )
