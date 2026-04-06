"""Country, currency acceptance, and nested money serializers."""

from rest_framework import serializers

from src.apps.finances.models import Currency
from src.apps.organizations.models import Country, CountryAcceptedCurrency


class CurrencyBriefSerializer(serializers.ModelSerializer):
    class Meta:
        model = Currency
        fields = ['id', 'code', 'symbol', 'name', 'numeric_code', 'minor_units']


class CountryBriefSerializer(serializers.ModelSerializer):
    class Meta:
        model = Country
        fields = ['id', 'iso_code2', 'iso_code3', 'name', 'flag', 'is_active']


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
