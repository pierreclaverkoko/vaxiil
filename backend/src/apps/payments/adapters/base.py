from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass
from decimal import Decimal
from typing import Any

from src.apps.payments.models import PaymentProvider, PaymentTransaction


@dataclass
class RefundResult:
    success: bool
    provider_reference: str
    response_code: str
    response_body: dict[str, Any]


@dataclass
class PaymentLinkResult:
    url: str
    link_id: str
    slug: str
    merchant_reference: str
    response_body: dict[str, Any]


class PaymentProviderAdapter(ABC):
    """Provider-specific payment operations (links, refunds, captures, etc.)."""

    def __init__(self, provider: PaymentProvider):
        self.provider = provider

    @abstractmethod
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
        """Create a hosted checkout payment link."""

    @abstractmethod
    def refund(
        self,
        *,
        transaction: PaymentTransaction,
        amount: Decimal,
        currency_code: str,
        idempotency_key: str,
    ) -> RefundResult:
        """Execute a refund against the provider."""


def get_adapter_for_provider(provider: PaymentProvider) -> PaymentProviderAdapter:
    """Resolve adapter implementation from provider code."""
    from src.apps.payments.adapters.mainmoney import MainmoneyPaymentAdapter
    from src.apps.payments.adapters.stub import StubPaymentAdapter

    code = (provider.code or '').lower()
    if code in ('mainmoney', 'mm'):
        return MainmoneyPaymentAdapter(provider)
    if code.startswith('stub') or code == 'test':
        return StubPaymentAdapter(provider)
    # Default until real integrations are registered per code.
    return StubPaymentAdapter(provider)
