from rest_framework import serializers

from src.apps.finances.models import Currency


class CurrencySerializer(serializers.ModelSerializer):
    class Meta:
        model = Currency
        fields = [
            'id',
            'code',
            'symbol',
            'name',
            'numeric_code',
            'minor_units',
            'is_active',
        ]
        read_only_fields = fields
