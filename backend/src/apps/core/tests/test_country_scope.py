"""Country scope resolution, middleware, and geo-country endpoint."""

from __future__ import annotations

from django.test import RequestFactory, TestCase, override_settings
from rest_framework import status
from rest_framework.test import APIClient

from src.apps.core.country_scope import (
    clear_timezone_map_cache,
    iso2_from_accept_language,
    iso2_from_timezone,
    resolve_country,
)
from src.apps.core.middleware import RESOLVED_COUNTRY_HEADER, CountryScopeMiddleware
from src.apps.test_helpers.geo import seed_cities_country, seed_us_country_and_currency
from src.apps.organizations.models import Country


class CountryScopeHelpersTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.us, _ = seed_us_country_and_currency()
        cities_cm, _ = seed_cities_country(
            code='CM',
            code3='CMR',
            name='Cameroon',
            city_name='Douala',
            lng=9.7,
            lat=4.05,
        )
        cls.cm, _ = Country.objects.get_or_create(
            cities_country=cities_cm,
            defaults={'flag': '', 'is_active': True},
        )
        cities_fr, _ = seed_cities_country(
            code='FR',
            code3='FRA',
            name='France',
            city_name='Paris',
            lng=2.35,
            lat=48.85,
        )
        cls.fr, _ = Country.objects.get_or_create(
            cities_country=cities_fr,
            defaults={'flag': '', 'is_active': True},
        )

    def setUp(self):
        self.factory = RequestFactory()
        clear_timezone_map_cache()

    def test_iso2_from_accept_language_region(self):
        self.assertEqual(iso2_from_accept_language('fr-CM,fr;q=0.9'), 'CM')
        self.assertEqual(iso2_from_accept_language('zh-Hans-CN'), 'CN')
        self.assertIsNone(iso2_from_accept_language('fr'))

    def test_iso2_from_timezone_zone_tab(self):
        self.assertEqual(iso2_from_timezone('Africa/Douala'), 'CM')
        self.assertEqual(iso2_from_timezone('America/New_York'), 'US')
        self.assertIsNone(iso2_from_timezone('Etc/UTC'))

    def test_x_country_wins_over_timezone_and_locale(self):
        request = self.factory.get('/')
        request.META['HTTP_X_COUNTRY'] = 'US'
        request.META['HTTP_X_TIMEZONE'] = 'Africa/Douala'
        request.META['HTTP_ACCEPT_LANGUAGE'] = 'fr-CM'
        country = resolve_country(request)
        self.assertEqual(country.pk, self.us.pk)

    def test_timezone_wins_over_accept_language(self):
        request = self.factory.get('/')
        request.META['HTTP_X_TIMEZONE'] = 'Africa/Douala'
        request.META['HTTP_ACCEPT_LANGUAGE'] = 'en-US'
        country = resolve_country(request)
        self.assertEqual(country.pk, self.cm.pk)

    def test_cdn_wins_over_timezone(self):
        request = self.factory.get('/')
        request.META['HTTP_CF_IPCOUNTRY'] = 'FR'
        request.META['HTTP_X_TIMEZONE'] = 'Africa/Douala'
        country = resolve_country(request)
        self.assertEqual(country.pk, self.fr.pk)

    def test_ignore_x_country_for_detect(self):
        request = self.factory.get('/')
        request.META['HTTP_X_COUNTRY'] = 'US'
        request.META['HTTP_X_TIMEZONE'] = 'Africa/Douala'
        country = resolve_country(request, ignore_x_country=True)
        self.assertEqual(country.pk, self.cm.pk)

    def test_middleware_sets_request_and_response_header(self):
        request = self.factory.get('/')
        request.META['HTTP_X_COUNTRY'] = 'CM'
        middleware = CountryScopeMiddleware(get_response=lambda r: __import__('django.http', fromlist=['HttpResponse']).HttpResponse())
        middleware.process_request(request)
        self.assertEqual(request.country.pk, self.cm.pk)
        from django.http import HttpResponse

        response = HttpResponse()
        out = middleware.process_response(request, response)
        self.assertEqual(out[RESOLVED_COUNTRY_HEADER], 'CM')


class GeoCountryAPITests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.us, _ = seed_us_country_and_currency()
        cities_cm, _ = seed_cities_country(
            code='CM',
            code3='CMR',
            name='Cameroon',
            city_name='Yaounde',
            lng=11.5,
            lat=3.87,
        )
        cls.cm, _ = Country.objects.get_or_create(
            cities_country=cities_cm,
            defaults={'flag': '', 'is_active': True},
        )

    def setUp(self):
        self.client = APIClient()
        clear_timezone_map_cache()

    def test_geo_country_from_timezone(self):
        res = self.client.get(
            '/api/v1/organizations/geo-country/',
            HTTP_X_TIMEZONE='Africa/Douala',
            HTTP_ACCEPT_LANGUAGE='en-US',
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['id'], str(self.cm.id))
        self.assertEqual(res['X-Resolved-Country'], 'CM')

    def test_geo_country_ignores_x_country(self):
        res = self.client.get(
            '/api/v1/organizations/geo-country/',
            HTTP_X_COUNTRY='US',
            HTTP_X_TIMEZONE='Africa/Douala',
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['id'], str(self.cm.id))

    def test_geo_country_empty_returns_204(self):
        res = self.client.get(
            '/api/v1/organizations/geo-country/',
            HTTP_ACCEPT_LANGUAGE='fr',
        )
        self.assertEqual(res.status_code, status.HTTP_204_NO_CONTENT)
