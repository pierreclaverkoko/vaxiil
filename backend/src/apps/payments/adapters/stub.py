from __future__ import annotations

import uuid
from decimal import Decimal
from typing import Any

from src.apps.payments.adapters.base import (
    PaymentLinkResult,
    PaymentProviderAdapter,
    RefundResult,
)
from src.apps.payments.models import PaymentTransaction


class StubPaymentAdapter(PaymentProviderAdapter):
    """Test / placeholder adapter — no external API calls."""

    def create_payment_link(
        self,
        *,
        amount: Decimal,
        currency_code: str,
        merchant_reference: str,
        redirect_url: str | None = None,
        title: str | None = None,
        description: str | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> PaymentLinkResult:
        link_id = f'stub_link_{uuid.uuid4().hex[:12]}'
        slug = f'stub-{uuid.uuid4().hex[:8]}'
        url = f'https://pay.example.test/l/{slug}'
        body: dict[str, Any] = {
            'stub': True,
            'id': link_id,
            'slug': slug,
            'url': url,
            'merchantReference': merchant_reference,
            'amount': str(amount),
            'currencyCode': currency_code,
            'redirectUrl': redirect_url,
            'title': title,
            'description': description,
            'metadata': metadata or {},
        }
        return PaymentLinkResult(
            url=url,
            link_id=link_id,
            slug=slug,
            merchant_reference=merchant_reference,
            response_body=body,
        )

    def refund(
        self,
        *,
        transaction: PaymentTransaction,
        amount: Decimal,
        currency_code: str,
        idempotency_key: str,
    ) -> RefundResult:
        ref = f'stub_refund_{uuid.uuid4().hex[:16]}'
        body: dict[str, Any] = {
            'stub': True,
            'amount': str(amount),
            'currency': currency_code,
            'idempotency_key': idempotency_key,
        }
        return RefundResult(
            success=True,
            provider_reference=ref,
            response_code='200',
            response_body=body,
        )
