"""Read-only serializers for PaymentConnector / PaymentMethod catalog."""

from __future__ import annotations

from django.utils.translation import get_language
from django_drf_dynamics.serializers.fields import ChoiceEnumField
from rest_framework import serializers

from src.apps.payments.catalog import PaymentConnector, PaymentMethod
from src.apps.payments.identifier_ui import (
    account_placeholder_for_method,
    identifier_type_for_method,
    phone_country_codes_for_method,
)


class PaymentConnectorBriefSerializer(serializers.ModelSerializer):
    connector_type = ChoiceEnumField()

    class Meta:
        model = PaymentConnector
        fields = [
            'id',
            'code',
            'name',
            'connector_type',
            'adapter_key',
            'is_active',
        ]
        read_only_fields = fields


class PaymentMethodSerializer(serializers.ModelSerializer):
    method_type = ChoiceEnumField()
    connector = PaymentConnectorBriefSerializer(read_only=True)
    country_code = serializers.SerializerMethodField()
    currency_code = serializers.SerializerMethodField()
    logo_url = serializers.SerializerMethodField()
    destination_fields = serializers.SerializerMethodField()
    identifier_type = serializers.SerializerMethodField()
    account_placeholder = serializers.SerializerMethodField()
    phone_country_codes = serializers.SerializerMethodField()

    class Meta:
        model = PaymentMethod
        fields = [
            'id',
            'code',
            'name',
            'logo_url',
            'method_type',
            'country',
            'country_code',
            'currency',
            'currency_code',
            'account_regex',
            'config',
            'destination_fields',
            'identifier_type',
            'account_placeholder',
            'phone_country_codes',
            'supported_operations',
            'connector',
            'is_active',
        ]
        read_only_fields = fields

    def get_country_code(self, obj):
        if not obj.country_id:
            return None
        return getattr(obj.country, 'iso_code2', None) or None

    def get_currency_code(self, obj):
        return obj.currency.code if obj.currency_id else None

    def get_logo_url(self, obj):
        if not obj.logo:
            return None
        request = self.context.get('request')
        try:
            url = obj.logo.url
        except ValueError:
            return None
        if request is not None:
            return request.build_absolute_uri(url)
        return url

    def get_destination_fields(self, obj):
        from src.apps.finances.services.settlement import destination_fields_for_method

        return destination_fields_for_method(obj)

    def get_identifier_type(self, obj):
        return identifier_type_for_method(obj)

    def get_account_placeholder(self, obj):
        return account_placeholder_for_method(obj, get_language())

    def get_phone_country_codes(self, obj):
        return phone_country_codes_for_method(obj)


class PaymentMethodBriefSerializer(serializers.ModelSerializer):
    method_type = ChoiceEnumField()
    logo_url = serializers.SerializerMethodField()
    connector_code = serializers.CharField(source='connector.code', read_only=True)
    country_code = serializers.SerializerMethodField()
    currency_code = serializers.SerializerMethodField()
    destination_fields = serializers.SerializerMethodField()
    identifier_type = serializers.SerializerMethodField()
    account_placeholder = serializers.SerializerMethodField()
    phone_country_codes = serializers.SerializerMethodField()

    class Meta:
        model = PaymentMethod
        fields = [
            'id',
            'code',
            'name',
            'logo_url',
            'method_type',
            'connector_code',
            'country_code',
            'currency_code',
            'account_regex',
            'destination_fields',
            'identifier_type',
            'account_placeholder',
            'phone_country_codes',
            'supported_operations',
        ]
        read_only_fields = fields

    def get_logo_url(self, obj):
        if not obj.logo:
            return None
        request = self.context.get('request')
        try:
            url = obj.logo.url
        except ValueError:
            return None
        if request is not None:
            return request.build_absolute_uri(url)
        return url

    def get_country_code(self, obj):
        if not obj.country_id:
            return None
        return getattr(obj.country, 'iso_code2', None) or None

    def get_currency_code(self, obj):
        return obj.currency.code if obj.currency_id else None

    def get_destination_fields(self, obj):
        from src.apps.finances.services.settlement import destination_fields_for_method

        return destination_fields_for_method(obj)

    def get_identifier_type(self, obj):
        return identifier_type_for_method(obj)

    def get_account_placeholder(self, obj):
        return account_placeholder_for_method(obj, get_language())

    def get_phone_country_codes(self, obj):
        return phone_country_codes_for_method(obj)
