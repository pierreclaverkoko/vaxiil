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
    minimum_settlement_amount,
    validate_settlement_account_fields,
)
from src.apps.payments.catalog import PaymentMethod
from src.apps.payments.catalog_serializers import PaymentMethodBriefSerializer


class SettlementAccountSerializer(serializers.ModelSerializer):
    method = PaymentMethodBriefSerializer(read_only=True)
    method_id = serializers.UUIDField(write_only=True, required=False)
    method_code = serializers.SlugField(write_only=True, required=False)
    details = serializers.JSONField(required=False)

    class Meta:
        model = SettlementAccount
        fields = [
            'id',
            'method',
            'method_id',
            'method_code',
            'label',
            'is_default',
            'account_identifier',
            'account_name',
            'details',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['id', 'method', 'created_at', 'updated_at']

    def _resolve_method(self, attrs):
        method = None
        method_id = attrs.pop('method_id', None)
        method_code = attrs.pop('method_code', None)
        if method_id:
            method = PaymentMethod.objects.filter(pk=method_id, is_active=True).first()
        elif method_code:
            method = PaymentMethod.objects.filter(
                code__iexact=method_code, is_active=True
            ).first()
        elif self.instance is not None:
            method = self.instance.method
        if method is None:
            raise serializers.ValidationError(
                {'method': _('Payment method is required.')}
            )
        return method

    def validate(self, attrs):
        method = self._resolve_method(attrs)
        attrs['method'] = method
        data = {
            'account_identifier': attrs.get(
                'account_identifier',
                getattr(self.instance, 'account_identifier', '') if self.instance else '',
            ),
            'account_name': attrs.get(
                'account_name',
                getattr(self.instance, 'account_name', '') if self.instance else '',
            ),
            'details': attrs.get(
                'details',
                getattr(self.instance, 'details', {}) if self.instance else {},
            ),
        }
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
    currency_code = serializers.CharField(source='currency.code', read_only=True)

    class Meta:
        model = SettlementRequest
        fields = [
            'id',
            'amount',
            'currency',
            'currency_code',
            'status',
            'method_code',
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
