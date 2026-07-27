"""Business settlement serializers and ViewSet helpers."""

from __future__ import annotations

from decimal import Decimal

from django.utils.translation import gettext_lazy as _
from django_drf_dynamics.serializers.fields import ChoiceEnumField
from rest_framework import serializers

from src.apps.finances.models import (
    OrganizationRevenueLedger,
    OrganizationRevenueWallet,
    SettlementAccount,
    SettlementRequest,
    SettlementSettings,
)
from src.apps.finances.services.inscription import available_settlement_balance
from src.apps.finances.services.settlement import (
    ACCEPTED_MOBILE_MONEY_COUNTRY_CODES,
    minimum_settlement_amount,
    validate_settlement_account_fields,
)
from src.apps.organizations.models import Country


class SettlementAccountSerializer(serializers.ModelSerializer):
    method = ChoiceEnumField()
    bank_country_id = serializers.UUIDField(
        source='bank_country.id', read_only=True, allow_null=True
    )
    mobile_money_country_id = serializers.UUIDField(
        source='mobile_money_country.id', read_only=True, allow_null=True
    )
    bank_country = serializers.PrimaryKeyRelatedField(
        queryset=Country.objects.all(),
        required=False,
        allow_null=True,
    )
    mobile_money_country = serializers.PrimaryKeyRelatedField(
        queryset=Country.objects.all(),
        required=False,
        allow_null=True,
    )

    class Meta:
        model = SettlementAccount
        fields = [
            'id',
            'method',
            'label',
            'is_default',
            'account_holder_name',
            'iban',
            'bic_swift',
            'bank_name',
            'bank_country',
            'bank_country_id',
            'phone_number',
            'mobile_money_country',
            'mobile_money_country_id',
            'interac_email',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'bank_country_id', 'mobile_money_country_id']

    def validate(self, attrs):
        method = attrs.get('method') or getattr(self.instance, 'method', None)
        data = {**attrs}
        if self.instance:
            for f in (
                'iban',
                'account_holder_name',
                'phone_number',
                'mobile_money_country',
                'interac_email',
            ):
                if f not in data:
                    data[f] = getattr(self.instance, f)
        validate_settlement_account_fields(method=method, data=data)
        return attrs


class SettlementSettingsSerializer(serializers.ModelSerializer):
    periodicity = ChoiceEnumField()
    currency_code = serializers.CharField(source='currency.code', read_only=True)
    minimum_floor = serializers.SerializerMethodField()

    class Meta:
        model = SettlementSettings
        fields = [
            'periodicity',
            'minimum_amount',
            'currency',
            'currency_code',
            'minimum_floor',
            'updated_at',
        ]
        read_only_fields = ['currency_code', 'minimum_floor', 'updated_at']

    def get_minimum_floor(self, obj):
        try:
            return str(minimum_settlement_amount(currency=obj.currency))
        except Exception:
            return str(obj.minimum_amount)

    def validate_minimum_amount(self, value):
        currency = self.instance.currency if self.instance else self.initial_data.get('currency')
        if self.instance:
            floor = minimum_settlement_amount(currency=self.instance.currency)
            if Decimal(value) < floor:
                raise serializers.ValidationError(
                    _('Minimum must be at least %(min)s %(code)s.')
                    % {'min': floor, 'code': self.instance.currency.code}
                )
        return value


class SettlementRequestBusinessSerializer(serializers.ModelSerializer):
    """Business-facing: never includes confirmation_image."""

    status = ChoiceEnumField()
    method = ChoiceEnumField()
    currency_code = serializers.CharField(source='currency.code', read_only=True)

    class Meta:
        model = SettlementRequest
        fields = [
            'id',
            'amount',
            'currency',
            'currency_code',
            'status',
            'method',
            'destination_snapshot',
            'staff_note',
            'created_at',
            'processed_at',
        ]
        read_only_fields = fields


class SettlementRequestCreateSerializer(serializers.Serializer):
    amount = serializers.DecimalField(max_digits=14, decimal_places=2)
    account_id = serializers.UUIDField()
    currency_code = serializers.CharField(max_length=3, required=False)


class RevenueBalanceSerializer(serializers.Serializer):
    currency_code = serializers.CharField()
    balance = serializers.CharField()
    available = serializers.CharField()


class RevenueLedgerSerializer(serializers.ModelSerializer):
    kind = ChoiceEnumField()
    currency_code = serializers.CharField(source='wallet.currency.code', read_only=True)

    class Meta:
        model = OrganizationRevenueLedger
        fields = [
            'id',
            'kind',
            'amount',
            'balance_after',
            'reason',
            'currency_code',
            'created_at',
        ]
        read_only_fields = fields


def revenue_balances_payload(organization) -> list[dict]:
    wallets = OrganizationRevenueWallet.objects.filter(
        organization=organization
    ).select_related('currency')
    return [
        {
            'currency_code': w.currency.code,
            'balance': str(w.balance),
            'available': str(available_settlement_balance(w)),
        }
        for w in wallets
    ]


# Silence unused import warning for ACCEPTED set (exported for clients via docs).
_ = ACCEPTED_MOBILE_MONEY_COUNTRY_CODES
