"""Pull payment status from the provider and apply local outcomes."""

from __future__ import annotations

from typing import Any

from django.utils import timezone

from src.apps.payments.adapters.base import get_adapter_for_provider
from src.apps.payments.models import PaymentTransaction
from src.apps.payments.services.webhooks import apply_payment_outcome

_FAILED_STATUSES = frozenset(
    {
        'FAILED',
        'FAILURE',
        'CANCELLED',
        'CANCELED',
        'DECLINED',
        'ERROR',
        'REJECTED',
    }
)


def refresh_deposit_status(txn: PaymentTransaction) -> PaymentTransaction:
    """
    Ask the payment provider for the current deposit status and apply
    SUCCESS / FAILED locally. Pending leaves the DB row unchanged.
    """
    provider = txn.payment_provider
    if provider is None:
        return txn

    adapter = get_adapter_for_provider(provider)
    try:
        result = adapter.check_deposit_status(reference=txn.client_reference)
    except NotImplementedError:
        return txn

    status_raw = (result.status or '').upper()
    update_fields: list[str] = []
    if result.provider_reference and not txn.provider_reference:
        txn.provider_reference = result.provider_reference
        update_fields.append('provider_reference')

    body = dict(txn.provider_response_body or {})
    if result.internal_reference:
        body['internal_reference'] = result.internal_reference
    if result.response_body:
        body['status_check'] = result.response_body
        body['status_checked_at'] = timezone.now().isoformat()
    if body != (txn.provider_response_body or {}):
        txn.provider_response_body = body
        update_fields.append('provider_response_body')

    if update_fields:
        txn.save(update_fields=update_fields)

    refreshed = PaymentTransaction.objects.filter(pk=txn.pk).first() or txn

    if result.pending:
        return refreshed

    succeeded: bool | None = None
    if status_raw in ('SUCCESS', 'SUCCEEDED', 'COMPLETED'):
        succeeded = True
    elif status_raw in _FAILED_STATUSES:
        succeeded = False

    if succeeded is None:
        return refreshed

    updated = apply_payment_outcome(
        merchant_reference=txn.client_reference,
        succeeded=succeeded,
        webhook_payload=_status_check_payload(result.response_body),
    )
    return updated or PaymentTransaction.objects.filter(pk=txn.pk).first() or txn


def _status_check_payload(body: dict[str, Any] | None) -> dict[str, Any] | None:
    if not isinstance(body, dict):
        return None
    return {'source': 'status_check', **body}
