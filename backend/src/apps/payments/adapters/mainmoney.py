from __future__ import annotations

import json
import logging
import time
import urllib.error
import urllib.request
from decimal import Decimal
from typing import Any

from django.conf import settings

from src.apps.payments.adapters.base import (
    PaymentLinkResult,
    PaymentProviderAdapter,
    RefundResult,
)
from src.apps.payments.models import PaymentTransaction

logger = logging.getLogger(__name__)

_token_cache: dict[str, Any] = {
    'access_token': None,
    'expires_at': 0.0,
}


class MainmoneyPaymentAdapter(PaymentProviderAdapter):
    """Mainmoney developer API — OAuth client credentials + payment links."""

    def _base_url(self) -> str:
        return (getattr(settings, 'MAINMONEY_API_BASE', '') or '').rstrip('/')

    def _client_id(self) -> str:
        cfg = self.provider.config or {}
        return cfg.get('client_id') or getattr(settings, 'MAINMONEY_CLIENT_ID', '')

    def _client_secret(self) -> str:
        cfg = self.provider.config or {}
        return cfg.get('client_secret') or getattr(
            settings, 'MAINMONEY_CLIENT_SECRET', ''
        )

    def _request(
        self,
        method: str,
        path: str,
        *,
        body: dict[str, Any] | None = None,
        bearer: str | None = None,
    ) -> dict[str, Any]:
        url = f'{self._base_url()}{path}'
        data = None
        headers = {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
        }
        if bearer:
            headers['Authorization'] = f'Bearer {bearer}'
        if body is not None:
            data = json.dumps(body).encode('utf-8')
        req = urllib.request.Request(url, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                raw = resp.read().decode('utf-8')
                if not raw:
                    return {}
                return json.loads(raw)
        except urllib.error.HTTPError as exc:
            err_body = exc.read().decode('utf-8', errors='replace')
            logger.warning('Mainmoney HTTP %s %s: %s', exc.code, path, err_body)
            raise RuntimeError(f'Mainmoney API error {exc.code}: {err_body}') from exc

    def _get_access_token(self) -> str:
        now = time.time()
        cached = _token_cache.get('access_token')
        expires_at = float(_token_cache.get('expires_at') or 0)
        if cached and now < expires_at - 60:
            return cached

        payload = {
            'client_id': self._client_id(),
            'client_secret': self._client_secret(),
            'grant_type': 'client_credentials',
        }
        # Docs: POST /developers/oauth/token
        resp = self._request('POST', '/developers/oauth/token', body=payload)
        data = resp.get('data') or resp
        token = data.get('access_token')
        if not token:
            raise RuntimeError('Mainmoney OAuth response missing access_token')
        expires_in = int(data.get('expires_in') or 3600)
        _token_cache['access_token'] = token
        _token_cache['expires_at'] = now + expires_in
        return token

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
        token = self._get_access_token()
        body: dict[str, Any] = {
            'amount': float(amount),
            'currencyCode': currency_code,
            'merchantReference': merchant_reference,
        }
        if redirect_url:
            body['redirectUrl'] = redirect_url
        if title:
            body['title'] = title
        if description:
            body['description'] = description
        if metadata:
            body['metadata'] = metadata

        resp = self._request(
            'POST',
            '/developers/v1/payment-links',
            body=body,
            bearer=token,
        )
        data = resp.get('data') or resp
        link_id = str(data.get('id') or '')
        slug = str(data.get('slug') or '')
        url = str(data.get('url') or '')
        if not url:
            raise RuntimeError('Mainmoney payment-link response missing url')
        return PaymentLinkResult(
            url=url,
            link_id=link_id,
            slug=slug,
            merchant_reference=str(
                data.get('merchantReference') or merchant_reference
            ),
            response_body=resp if isinstance(resp, dict) else {'data': data},
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
        # Refund API not documented in payment_integration docs yet — soft stub.
        logger.info(
            'Mainmoney refund not implemented; recording local stub for %s',
            transaction.id,
        )
        return RefundResult(
            success=True,
            provider_reference=f'mm_refund_pending_{idempotency_key[:16]}',
            response_code='not_implemented',
            response_body={
                'note': 'Mainmoney refund API not wired; ledger refund recorded locally',
                'amount': str(amount),
                'currency': currency_code,
            },
        )
