from __future__ import annotations

from typing import Any

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from src.apps.bookings.models import Booking
from src.apps.finances.services.platform_fees import accrue_platform_fee_for_booking
from src.apps.payments.models import PaymentTransaction
from src.apps.payments.services.signatures import (
    verify_redirect_signature,
    verify_webhook_signature,
)


def _signing_secret() -> str:
    return getattr(settings, 'MAINMONEY_WEBHOOK_SIGNING_SECRET', '') or ''


def apply_payment_outcome(
    *,
    merchant_reference: str,
    succeeded: bool,
    webhook_payload: dict[str, Any] | None = None,
    signature_valid: bool | None = None,
) -> PaymentTransaction | None:
    """Idempotently mark a PENDING/PROCESSING payment succeeded or failed."""
    with transaction.atomic():
        txn = (
            PaymentTransaction.objects.select_for_update()
            .select_related('booking')
            .filter(
                client_reference=merchant_reference,
                kind=PaymentTransaction.TransactionKind.PAYMENT,
            )
            .order_by('-created_at')
            .first()
        )
        if txn is None:
            return None

        terminal = (
            PaymentTransaction.TransactionStatus.SUCCEEDED,
            PaymentTransaction.TransactionStatus.FAILED,
            PaymentTransaction.TransactionStatus.CANCELLED,
        )
        if txn.status in terminal:
            return txn

        txn.status = (
            PaymentTransaction.TransactionStatus.SUCCEEDED
            if succeeded
            else PaymentTransaction.TransactionStatus.FAILED
        )
        if webhook_payload is not None:
            txn.webhook_payload = webhook_payload
            txn.webhook_received_at = timezone.now()
        if signature_valid is not None:
            txn.webhook_signature_valid = signature_valid
        txn.save()

        if succeeded:
            booking = txn.booking
            if booking.status == Booking.BookingStatus.REQUESTED:
                booking.confirm()
            elif booking.status == Booking.BookingStatus.DRAFT:
                booking.confirm()
            accrue_platform_fee_for_booking(booking, payment_transaction=txn)

        return txn


def handle_mainmoney_webhook(
    *,
    raw_body: bytes,
    signature_header: str,
    event_header: str,
    payload: dict[str, Any],
) -> tuple[bool, str]:
    """
    Verify and process a Mainmoney webhook.

    Returns (ok, message).
    """
    secret = _signing_secret()
    valid = verify_webhook_signature(
        secret=secret,
        raw_body=raw_body,
        signature=signature_header or '',
    )
    if not valid:
        return False, 'invalid_signature'

    data = payload.get('data') or {}
    reference = str(data.get('reference') or '')
    if not reference:
        return False, 'missing_reference'

    event = event_header or payload.get('event') or ''
    status_raw = str(data.get('status') or '').upper()
    succeeded = (
        event.endswith('.completed')
        or status_raw in ('COMPLETED', 'SUCCESS', 'SUCCEEDED')
    )
    if event.endswith('.failed') or status_raw in ('FAILED', 'FAILURE'):
        succeeded = False

    txn = apply_payment_outcome(
        merchant_reference=reference,
        succeeded=succeeded,
        webhook_payload=payload,
        signature_valid=True,
    )
    if txn is None:
        return True, 'unknown_reference'
    return True, 'processed'


def handle_redirect_callback(
    *,
    reference: str,
    status: str,
    amount: str,
    currency: str,
    timestamp: str,
    signature: str,
) -> tuple[bool, str]:
    secret = _signing_secret()
    valid = verify_redirect_signature(
        secret=secret,
        reference=reference,
        status=status,
        amount=amount,
        currency=currency,
        timestamp=timestamp,
        signature=signature,
    )
    if not valid:
        return False, 'invalid_signature'

    succeeded = status.lower() == 'completed'
    txn = apply_payment_outcome(
        merchant_reference=reference,
        succeeded=succeeded,
        webhook_payload={
            'source': 'redirect',
            'reference': reference,
            'status': status,
            'amount': amount,
            'currency': currency,
            'timestamp': timestamp,
        },
        signature_valid=True,
    )
    if txn is None:
        return True, 'unknown_reference'
    return True, 'processed'
