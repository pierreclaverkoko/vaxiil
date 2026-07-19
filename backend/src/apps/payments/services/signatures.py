from __future__ import annotations

import hashlib
import hmac


def hmac_sha256_hex(secret: str, payload: str | bytes) -> str:
    if isinstance(payload, str):
        payload_bytes = payload.encode('utf-8')
    else:
        payload_bytes = payload
    return hmac.new(
        secret.encode('utf-8'),
        payload_bytes,
        hashlib.sha256,
    ).hexdigest()


def constant_time_equals(a: str, b: str) -> bool:
    return hmac.compare_digest(a.lower(), b.lower())


def verify_webhook_signature(*, secret: str, raw_body: bytes, signature: str) -> bool:
    if not secret or not signature:
        return False
    expected = hmac_sha256_hex(secret, raw_body)
    return constant_time_equals(expected, signature)


def verify_redirect_signature(
    *,
    secret: str,
    reference: str,
    status: str,
    amount: str,
    currency: str,
    timestamp: str,
    signature: str,
) -> bool:
    if not secret or not signature:
        return False
    payload = f'{reference}|{status}|{amount}|{currency}|{timestamp}'
    expected = hmac_sha256_hex(secret, payload)
    return constant_time_equals(expected, signature)
