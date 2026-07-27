from __future__ import annotations

from typing import Any

from django.conf import settings
from django.db import transaction
from django.utils import timezone

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
        # Avoid select_related on nullable FKs with select_for_update (Postgres
        # rejects FOR UPDATE on the nullable side of an outer join).
        txn = (
            PaymentTransaction.objects.select_for_update()
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
            if txn.purpose == PaymentTransaction.Purpose.WALLET_TOP_UP:
                from src.apps.payments.models import RefundWalletLedger
                from src.apps.payments.services.wallet import credit_wallet

                if txn.user_id and txn.currency_id:
                    credit_wallet(
                        user=txn.user,
                        currency=txn.currency,
                        amount=txn.amount,
                        booking=None,
                        idempotency_key=f'topup-credit-{txn.pk}',
                        note='Store credit top-up',
                        kind=RefundWalletLedger.Kind.TOP_UP,
                    )
            elif txn.booking_id:
                booking = txn.booking
                # Keep status Requested; clients use is_paid until business confirms.
                accrue_platform_fee_for_booking(booking, payment_transaction=txn)
                from src.apps.finances.services.inscription import (
                    finalize_booking_platform_charges,
                )

                finalize_booking_platform_charges(
                    booking=booking,
                    payment_transaction=txn,
                )

            from src.apps.payments.notify import notify_payment_succeeded

            notify_payment_succeeded(txn)

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
