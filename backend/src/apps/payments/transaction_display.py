"""Helpers for consumer payment history display (method + identifier)."""

from __future__ import annotations

from uuid import UUID

from src.apps.payments.catalog import PaymentMethod
from src.apps.payments.models import PaymentTransaction


def mask_account_identifier(raw: str) -> str:
    """Light mask for stored payer account (keeps start + last 4)."""
    text = (raw or '').strip()
    if len(text) <= 6:
        return text
    return f'{text[:3]}•••{text[-4:]}'


def transaction_can_refresh_status(txn: PaymentTransaction) -> bool:
    """False for local store-credit refunds (no PSP deposit to poll)."""
    if txn.provider_response_code == 'wallet_credit':
        return False
    if txn.kind in (
        PaymentTransaction.TransactionKind.REFUND,
        PaymentTransaction.TransactionKind.PARTIAL_REFUND,
    ):
        body = txn.provider_response_body or {}
        if isinstance(body, dict) and body.get('destination') == 'wallet':
            return False
    return True


def payment_method_id_from_txn(txn: PaymentTransaction) -> str | None:
    payload = txn.provider_request_payload or {}
    if not isinstance(payload, dict):
        return None
    raw = payload.get('payment_method_id')
    if raw is None or raw == '':
        return None
    return str(raw)


def account_identifier_from_txn(txn: PaymentTransaction) -> str:
    if txn.payer_account_masked:
        return txn.payer_account_masked
    payload = txn.provider_request_payload or {}
    if not isinstance(payload, dict):
        return ''
    for key in ('customer_phone', 'account_identifier', 'phone'):
        raw = payload.get(key)
        if isinstance(raw, str) and raw.strip():
            return raw.strip()
    return ''


def prefetch_payment_methods_for_transactions(
    transactions,
) -> dict[str, PaymentMethod | None]:
    """Batch-load PaymentMethod rows referenced in transaction payloads."""
    ids: list[str] = []
    for txn in transactions:
        mid = payment_method_id_from_txn(txn)
        if mid:
            ids.append(mid)
    if not ids:
        return {}
    valid_ids = []
    for mid in ids:
        try:
            UUID(mid)
            valid_ids.append(mid)
        except (TypeError, ValueError):
            continue
    methods = {
        str(m.id): m
        for m in PaymentMethod.objects.select_related(
            'connector',
            'country',
        ).filter(pk__in=valid_ids)
    }
    return {mid: methods.get(mid) for mid in ids}
