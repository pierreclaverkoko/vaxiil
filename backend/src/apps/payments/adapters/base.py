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


@dataclass
class CollectResult:
    """Inbound collection (deposit) accepted by the provider."""

    success: bool
    pending: bool
    provider_reference: str
    internal_reference: str
    merchant_reference: str
    status: str
    response_body: dict[str, Any]
    message: str = ''


@dataclass
class PayoutResult:
    success: bool
    pending: bool
    provider_reference: str
    internal_reference: str
    merchant_reference: str
    status: str
    response_body: dict[str, Any]
    message: str = ''


class PaymentProviderAdapter(ABC):
    """Provider-specific payment operations (collect, refunds, payouts, legacy links)."""

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
        """Create a hosted checkout payment link (legacy / MainMoney)."""

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
        """Inbound collection (deposit). Override on aggregators."""
        raise NotImplementedError(
            f'{self.__class__.__name__} does not support collect()'
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
        """Outbound payout. Override on aggregators."""
        raise NotImplementedError(
            f'{self.__class__.__name__} does not support payout()'
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
        """Business payout (B2C phone or B2B merchant account)."""
        raise NotImplementedError(
            f'{self.__class__.__name__} does not support business_payout()'
        )

    @abstractmethod
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
        """Execute a refund against the provider."""


def get_adapter_for_provider(provider: PaymentProvider) -> PaymentProviderAdapter:
    """Resolve adapter implementation from provider code."""
    from src.apps.payments.adapters.mainmoney import MainmoneyPaymentAdapter
    from src.apps.payments.adapters.mm_aggregator import MmAggregatorPaymentAdapter
    from src.apps.payments.adapters.stub import StubPaymentAdapter

    code = (provider.code or '').lower()
    if code in ('mm_aggregator', 'mma'):
        return MmAggregatorPaymentAdapter(provider)
    if code in ('mainmoney', 'mm'):
        return MainmoneyPaymentAdapter(provider)
    if code.startswith('stub') or code == 'test':
        return StubPaymentAdapter(provider)
    # Default until real integrations are registered per code.
    return StubPaymentAdapter(provider)
