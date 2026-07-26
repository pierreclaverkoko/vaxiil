"""Shared reference data for tests (US + USD + default CAC + cities City)."""

from django.contrib.gis.geos import Point

from cities.models import City as CitiesCity
from cities.models import Continent
from cities.models import Country as CitiesCountry
from src.apps.finances.models import Currency
from src.apps.organizations.models import Country, CountryAcceptedCurrency, OrganizationAddress


def seed_cities_country(
    *,
    code='US',
    code3='USA',
    name='United States',
    city_name='New York',
    lng=-74.006,
    lat=40.7128,
):
    """Create minimal django-cities Continent/Country/City rows for tests."""
    continent, _ = Continent.objects.get_or_create(
        code='NA',
        defaults={'name': 'North America', 'slug': 'north-america'},
    )
    cities_country, _ = CitiesCountry.objects.get_or_create(
        code=code,
        defaults={
            'name': name,
            'code3': code3,
            'population': 1,
            'area': 1,
            'phone': '1',
            'tld': code.lower(),
            'postal_code_format': '',
            'postal_code_regex': '',
            'capital': city_name,
            'continent': continent,
            'slug': name.lower().replace(' ', '-'),
        },
    )
    city, _ = CitiesCity.objects.get_or_create(
        country=cities_country,
        name=city_name,
        defaults={
            'name_std': city_name,
            'location': Point(lng, lat, srid=4326),
            'population': 1,
            'kind': 'PPL',
            'timezone': 'UTC',
            'slug': f'{city_name.lower().replace(" ", "-")}',
        },
    )
    return cities_country, city


def seed_us_country_and_currency():
    """Return (Country, CountryAcceptedCurrency) for United States / USD."""
    cities_country, _city = seed_cities_country()
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
        cities_country=cities_country,
        defaults={
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
    cities_city = loc.get('cities_city')
    if cities_city is None:
        city_name = loc.get('city_name') or loc.get('city', 'New York')
        _cc, cities_city = seed_cities_country(
            code=country.iso_code2 or 'US',
            code3=country.iso_code3 or 'USA',
            name=country.name or 'United States',
            city_name=city_name,
        )
    return OrganizationAddress.objects.create(
        organization=organization,
        address=loc.get('address', '1 Main St'),
        cities_city=cities_city,
        postal_code=loc.get('postal_code', '10001'),
        country_text=loc.get('country_text', ''),
        country=country,
        is_primary=True,
        latitude=loc.get('latitude'),
        longitude=loc.get('longitude'),
    )
