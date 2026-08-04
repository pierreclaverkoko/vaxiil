from __future__ import annotations

from typing import Any
from uuid import UUID

from django_drf_dynamics.serializers.fields import ChoiceEnumField
from rest_framework import serializers

from src.apps.core.fields import choice_enum_dict
from src.apps.payments.catalog import PaymentMethod
from src.apps.payments.models import PaymentTransaction
from src.apps.payments.transaction_display import (
    account_identifier_from_txn,
    payment_method_id_from_txn,
    transaction_can_refresh_status,
)


class ConsumerPaymentTransactionSerializer(serializers.ModelSerializer):
    """User-scoped payment history row (booking payments, wallet top-ups, refunds)."""

    status = ChoiceEnumField()
    kind = ChoiceEnumField()
    purpose = ChoiceEnumField()
    provider_code = serializers.CharField(
        source='payment_provider.code',
        read_only=True,
    )
    currency_code = serializers.CharField(source='currency.code', read_only=True)
    booking = serializers.UUIDField(source='booking_id', read_only=True)
    payment_method = serializers.SerializerMethodField()
    account_identifier = serializers.SerializerMethodField()
    can_refresh_status = serializers.SerializerMethodField()

    class Meta:
        model = PaymentTransaction
        fields = [
            'id',
            'booking',
            'provider_code',
            'amount',
            'currency_code',
            'kind',
            'status',
            'purpose',
            'client_reference',
            'created_at',
            'updated_at',
            'payment_method',
            'account_identifier',
            'can_refresh_status',
        ]

    def _method_for(self, obj: PaymentTransaction) -> PaymentMethod | None:
        cache: dict[str, PaymentMethod | None] = self.context.setdefault(
            '_payment_methods_by_id',
            {},
        )
        method_id = payment_method_id_from_txn(obj)
        if not method_id:
            return None
        if method_id in cache:
            return cache[method_id]
        try:
            UUID(method_id)
        except (TypeError, ValueError):
            cache[method_id] = None
            return None
        method = (
            PaymentMethod.objects.select_related('connector', 'country')
            .filter(pk=method_id)
            .first()
        )
        cache[method_id] = method
        return method

    def get_payment_method(self, obj: PaymentTransaction) -> dict[str, Any] | None:
        method = self._method_for(obj)
        if method is None:
            return None
        request = self.context.get('request')
        logo_url = None
        if method.logo:
            try:
                url = method.logo.url
            except ValueError:
                url = None
            if url:
                logo_url = (
                    request.build_absolute_uri(url) if request is not None else url
                )
        country_payload = None
        country = method.country
        if country is not None:
            country_payload = {
                'id': str(country.id),
                'name': country.name,
                'iso_code2': country.iso_code2,
                'flag': country.flag or '',
            }
        return {
            'id': str(method.id),
            'code': method.code,
            'name': method.name,
            'logo_url': logo_url,
            'method_type': choice_enum_dict(method, 'method_type'),
            'country': country_payload,
        }

    def get_account_identifier(self, obj: PaymentTransaction) -> str:
        return account_identifier_from_txn(obj)

    def get_can_refresh_status(self, obj: PaymentTransaction) -> bool:
        return transaction_can_refresh_status(obj)


def serialize_consumer_transaction_detail(
    txn: PaymentTransaction,
    *,
    request=None,
    methods_by_id: dict | None = None,
) -> dict[str, Any]:
    """Full detail DTO plus legacy poll keys (transaction_id, booking_id, raw status)."""
    cache = methods_by_id
    if cache is None:
        from src.apps.payments.transaction_display import (
            prefetch_payment_methods_for_transactions,
        )

        cache = prefetch_payment_methods_for_transactions([txn])
    data = dict(
        ConsumerPaymentTransactionSerializer(
            txn,
            context={
                'request': request,
                '_payment_methods_by_id': cache,
            },
        ).data
    )
    # Legacy poll keys (payment-confirm / clients that expect a bare status char).
    data['transaction_id'] = str(txn.id)
    data['booking_id'] = str(txn.booking_id) if txn.booking_id else None
    data['status_code'] = txn.status
    return data

