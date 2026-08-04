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
    CollectResult,
    PaymentLinkResult,
    PaymentProviderAdapter,
    PayoutResult,
    RefundResult,
)
from src.apps.payments.models import PaymentTransaction

logger = logging.getLogger(__name__)

_token_cache: dict[str, Any] = {
    'access_token': None,
    'expires_at': 0.0,
}


class MmAggregatorPaymentAdapter(PaymentProviderAdapter):
    """MM Aggregator merchant API — token exchange + deposit/refund/payout."""

    def _base_url(self) -> str:
        return (getattr(settings, 'MM_AGGREGATOR_API_BASE', '') or '').rstrip('/')

    def _client_id(self) -> str:
        cfg = self.provider.config or {}
        return cfg.get('client_id') or getattr(settings, 'MM_AGGREGATOR_CLIENT_ID', '')

    def _client_secret(self) -> str:
        cfg = self.provider.config or {}
        return cfg.get('secret') or cfg.get('client_secret') or getattr(
            settings, 'MM_AGGREGATOR_CLIENT_SECRET', ''
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
            with urllib.request.urlopen(req, timeout=45) as resp:
                raw = resp.read().decode('utf-8')
                if not raw:
                    return {}
                return json.loads(raw)
        except urllib.error.HTTPError as exc:
            err_body = exc.read().decode('utf-8', errors='replace')
            logger.warning('MM Aggregator HTTP %s %s: %s', exc.code, path, err_body)
            raise RuntimeError(
                f'MM Aggregator API error {exc.code}: {err_body}'
            ) from exc

    def _get_access_token(self) -> str:
        now = time.time()
        cached = _token_cache.get('access_token')
        expires_at = float(_token_cache.get('expires_at') or 0)
        if cached and now < expires_at - 60:
            return cached

        payload = {
            'client_id': self._client_id(),
            'secret': self._client_secret(),
        }
        resp = self._request('POST', '/auth/tokens/exchange/', body=payload)
        data = resp.get('data') or resp
        token = data.get('access_token')
        if not token:
            raise RuntimeError('MM Aggregator token exchange missing access_token')
        expires_in = int(data.get('expires_in') or 3600)
        _token_cache['access_token'] = token
        _token_cache['expires_at'] = now + expires_in
        return token

    def _unwrap_data(self, resp: dict[str, Any]) -> dict[str, Any]:
        data = resp.get('data')
        if isinstance(data, dict):
            return data
        response_data = resp.get('response_data')
        if isinstance(response_data, dict):
            return response_data
        return resp if isinstance(resp, dict) else {}

    def _status_flags(self, status_raw: str) -> tuple[bool, bool]:
        status = (status_raw or '').upper()
        if status in ('SUCCESS', 'SUCCEEDED', 'COMPLETED'):
            return True, False
        if status in ('PENDING', 'PROCESSING', 'ACCEPTED', 'QUEUED'):
            return True, True
        return False, False

    def check_deposit_status(self, *, reference: str) -> CollectResult:
        """Pull deposit status from MM Aggregator (provider reconciliation)."""
        token = self._get_access_token()
        resp = self._request(
            'POST',
            '/transactions/status/check/deposit/',
            body={'reference': reference},
            bearer=token,
        )
        data = self._unwrap_data(resp)
        status_raw = str(data.get('status') or '')
        success, pending = self._status_flags(status_raw)
        if not status_raw and resp.get('success') is True:
            success, pending = True, True
            status_raw = 'PENDING'
        return CollectResult(
            success=success or pending,
            pending=pending,
            provider_reference=str(
                data.get('external_reference')
                or data.get('provider_reference')
                or data.get('transaction_id')
                or ''
            ),
            internal_reference=str(data.get('internal_reference') or ''),
            merchant_reference=str(
                data.get('merchant_reference') or reference
            ),
            status=status_raw or 'PENDING',
            response_body=resp if isinstance(resp, dict) else {'data': data},
            message=str(data.get('message') or resp.get('message') or ''),
        )

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
        raise NotImplementedError(
            'MM Aggregator does not use hosted payment links; use collect()'
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
        token = self._get_access_token()
        body: dict[str, Any] = {
            'provider_code': provider_code,
            'reference': merchant_reference,
            'amount': str(amount),
            'currency': currency_code,
            'customer_phone': customer_phone,
        }
        if customer_name:
            body['customer_name'] = customer_name
        if callback_url:
            body['callback_url'] = callback_url
        if metadata:
            body['metadata'] = metadata

        resp = self._request(
            'POST',
            '/transactions/deposits/',
            body=body,
            bearer=token,
        )
        data = self._unwrap_data(resp)
        status_raw = str(data.get('status') or '')
        success, pending = self._status_flags(status_raw)
        # HTTP-level acceptance: if outer success is true and status missing, treat pending
        if not status_raw and resp.get('success') is True:
            success, pending = True, True
            status_raw = 'PENDING'
        return CollectResult(
            success=success or pending,
            pending=pending or (success and status_raw.upper() not in (
                'SUCCESS',
                'SUCCEEDED',
                'COMPLETED',
            )),
            provider_reference=str(
                data.get('external_reference')
                or data.get('provider_reference')
                or data.get('transaction_id')
                or ''
            ),
            internal_reference=str(data.get('internal_reference') or ''),
            merchant_reference=str(
                data.get('merchant_reference') or merchant_reference
            ),
            status=status_raw or 'PENDING',
            response_body=resp if isinstance(resp, dict) else {'data': data},
            message=str(data.get('message') or resp.get('message') or ''),
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
        return self._execute_payout(
            path='/transactions/payouts/',
            amount=amount,
            currency_code=currency_code,
            merchant_reference=merchant_reference,
            provider_code=provider_code,
            destination_account=destination_account,
            destination_name=destination_name,
            purpose=purpose,
            purpose_code=purpose_code,
            callback_url=callback_url,
            metadata=metadata,
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
        path = (
            '/transactions/payouts/business/merchant-account/'
            if to_merchant_account
            else '/transactions/payouts/business/'
        )
        return self._execute_payout(
            path=path,
            amount=amount,
            currency_code=currency_code,
            merchant_reference=merchant_reference,
            provider_code=provider_code,
            destination_account=destination_account,
            destination_name=destination_name,
            purpose=purpose,
            purpose_code=purpose_code,
            callback_url=callback_url,
            metadata=metadata,
        )

    def _execute_payout(
        self,
        *,
        path: str,
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
        token = self._get_access_token()
        body: dict[str, Any] = {
            'provider_code': provider_code,
            'reference': merchant_reference,
            'amount': str(amount),
            'currency': currency_code,
            'destination_account': destination_account,
        }
        if destination_name:
            body['destination_name'] = destination_name
        if purpose:
            body['purpose'] = purpose
        if purpose_code:
            body['purpose_code'] = purpose_code
        if callback_url:
            body['callback_url'] = callback_url
        if metadata:
            body['metadata'] = metadata

        resp = self._request('POST', path, body=body, bearer=token)
        data = self._unwrap_data(resp)
        status_raw = str(data.get('status') or '')
        success, pending = self._status_flags(status_raw)
        if not status_raw and resp.get('success') is True:
            success, pending = True, True
            status_raw = 'PENDING'
        return PayoutResult(
            success=success or pending,
            pending=pending or (
                success
                and status_raw.upper()
                not in ('SUCCESS', 'SUCCEEDED', 'COMPLETED')
            ),
            provider_reference=str(
                data.get('external_reference')
                or data.get('provider_reference')
                or data.get('transaction_id')
                or ''
            ),
            internal_reference=str(data.get('internal_reference') or ''),
            merchant_reference=str(
                data.get('merchant_reference') or merchant_reference
            ),
            status=status_raw or 'PENDING',
            response_body=resp if isinstance(resp, dict) else {'data': data},
            message=str(data.get('message') or resp.get('message') or ''),
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
        token = self._get_access_token()
        original_ref = transaction.client_reference or ''
        provider_code = ''
        req = transaction.provider_request_payload or {}
        if isinstance(req, dict):
            provider_code = str(req.get('provider_code') or '')
        phone = customer_phone or ''
        if not phone and isinstance(req, dict):
            phone = str(req.get('customer_phone') or '')
        if not provider_code or not phone:
            logger.info(
                'MM Aggregator refund missing provider_code/phone; local stub for %s',
                transaction.id,
            )
            return RefundResult(
                success=True,
                provider_reference=f'mma_refund_local_{idempotency_key[:16]}',
                response_code='local_wallet',
                response_body={
                    'note': 'Insufficient provider metadata; refund handled locally',
                    'amount': str(amount),
                    'currency': currency_code,
                },
            )

        body: dict[str, Any] = {
            'provider_code': provider_code,
            'reference': f'ref_{idempotency_key[:40]}',
            'original_transaction_id': original_ref,
            'amount': str(amount),
            'currency': currency_code,
            'customer_phone': phone,
            'reason': reason or 'Refund',
        }
        if callback_url:
            body['callback_url'] = callback_url
        if metadata:
            body['metadata'] = metadata

        try:
            resp = self._request(
                'POST',
                '/transactions/refunds/',
                body=body,
                bearer=token,
            )
        except RuntimeError as exc:
            logger.warning('MM Aggregator refund failed: %s', exc)
            return RefundResult(
                success=False,
                provider_reference='',
                response_code='error',
                response_body={'error': str(exc)},
            )

        data = self._unwrap_data(resp)
        status_raw = str(data.get('status') or '').upper()
        ok = status_raw in (
            'SUCCESS',
            'SUCCEEDED',
            'COMPLETED',
            'PENDING',
            'PROCESSING',
        ) or resp.get('success') is True
        return RefundResult(
            success=ok,
            provider_reference=str(
                data.get('external_reference')
                or data.get('provider_reference')
                or data.get('transaction_id')
                or ''
            ),
            response_code=status_raw or ('ok' if ok else 'failed'),
            response_body=resp if isinstance(resp, dict) else {'data': data},
        )
