from __future__ import annotations

import uuid
from decimal import Decimal
from typing import Any

from src.apps.payments.adapters.base import (
    CollectResult,
    PaymentLinkResult,
    PaymentProviderAdapter,
    PayoutResult,
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

    def collect(
        self,
        *,
        amount: Decimal,
        currency_code: str,
        merchant_reference: str,
        provider_code: str,
        customer_phone: str,
        customer_name: str | None = None,
        callback_url: str | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> CollectResult:
        ref = f'stub_dep_{uuid.uuid4().hex[:12]}'
        body: dict[str, Any] = {
            'stub': True,
            'status': 'PENDING',
            'merchant_reference': merchant_reference,
            'provider_code': provider_code,
            'customer_phone': customer_phone,
            'amount': str(amount),
            'currency': currency_code,
            'callback_url': callback_url,
            'metadata': metadata or {},
        }
        return CollectResult(
            success=True,
            pending=True,
            provider_reference=ref,
            internal_reference=ref,
            merchant_reference=merchant_reference,
            status='PENDING',
            response_body=body,
            message='Stub deposit accepted',
        )

    def payout(
        self,
        *,
        amount: Decimal,
        currency_code: str,
        merchant_reference: str,
        provider_code: str,
        destination_account: str,
        destination_name: str | None = None,
        purpose: str | None = None,
        purpose_code: str | None = None,
        callback_url: str | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> PayoutResult:
        ref = f'stub_po_{uuid.uuid4().hex[:12]}'
        return PayoutResult(
            success=True,
            pending=True,
            provider_reference=ref,
            internal_reference=ref,
            merchant_reference=merchant_reference,
            status='PENDING',
            response_body={'stub': True, 'destination': destination_account},
            message='Stub payout accepted',
        )

    def business_payout(
        self,
        *,
        amount: Decimal,
        currency_code: str,
        merchant_reference: str,
        provider_code: str,
        destination_account: str,
        destination_name: str | None = None,
        purpose: str,
        purpose_code: str | None = None,
        callback_url: str | None = None,
        metadata: dict[str, Any] | None = None,
        to_merchant_account: bool = False,
    ) -> PayoutResult:
        return self.payout(
            amount=amount,
            currency_code=currency_code,
            merchant_reference=merchant_reference,
            provider_code=provider_code,
            destination_account=destination_account,
            destination_name=destination_name,
            purpose=purpose,
            purpose_code=purpose_code,
            callback_url=callback_url,
            metadata={
                **(metadata or {}),
                'is_business': True,
                'to_merchant_account': to_merchant_account,
            },
        )

    def refund(
        self,
        *,
        transaction: PaymentTransaction,
        amount: Decimal,
        currency_code: str,
        idempotency_key: str,
        customer_phone: str | None = None,
        reason: str = '',
        callback_url: str | None = None,
        metadata: dict[str, Any] | None = None,
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
