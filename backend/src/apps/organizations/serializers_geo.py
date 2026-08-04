"""Country, currency acceptance, city, and nested money serializers."""

from rest_framework import serializers

from cities.models import City
from src.apps.finances.models import Currency
from src.apps.organizations.models import Country, CountryAcceptedCurrency


class CurrencyBriefSerializer(serializers.ModelSerializer):
    class Meta:
        model = Currency
        fields = ['id', 'code', 'symbol', 'name', 'numeric_code', 'minor_units']


class CountryBriefSerializer(serializers.ModelSerializer):
    iso_code2 = serializers.CharField(read_only=True)
    iso_code3 = serializers.CharField(read_only=True)
    name = serializers.CharField(read_only=True)
    phone_code = serializers.SerializerMethodField()

    class Meta:
        model = Country
        fields = [
            'id',
            'iso_code2',
            'iso_code3',
            'name',
            'flag',
            'is_active',
            'phone_code',
        ]

    def get_phone_code(self, obj):
        cities = getattr(obj, 'cities_country', None)
        if cities is None:
            return None
        phone = getattr(cities, 'phone', None)
        if phone is None:
            return None
        text = str(phone).strip()
        return text or None


class CityBriefSerializer(serializers.ModelSerializer):
    class Meta:
        model = City
        fields = ['id', 'name', 'name_std', 'timezone', 'population']


class CountryAcceptedCurrencySerializer(serializers.ModelSerializer):
    currency = CurrencyBriefSerializer(read_only=True)

    class Meta:
        model = CountryAcceptedCurrency
        fields = [
            'id',
            'country',
            'currency',
            'is_active',
            'is_default',
        ]
        read_only_fields = fields
