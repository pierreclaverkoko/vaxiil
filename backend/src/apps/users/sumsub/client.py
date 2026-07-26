"""Sumsub App Token HMAC client (see docs/integrations/sumsub.json)."""

from __future__ import annotations

import hashlib
import hmac
import json
import logging
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Any
from urllib.parse import urlencode

from django.conf import settings

logger = logging.getLogger(__name__)


class SumsubError(RuntimeError):
    """Raised when the Sumsub API returns an error or is misconfigured."""


def external_user_id_for(user) -> str:
    """Stable Sumsub externalUserId / SDK userId (User UUID as string)."""
    return str(user.pk)


def _base_url() -> str:
    return (getattr(settings, 'SUMSUB_BASE_URL', '') or 'https://api.sumsub.com').rstrip(
        '/'
    )


def _app_token() -> str:
    return getattr(settings, 'SUMSUB_APP_TOKEN', '') or ''


def _secret_key() -> str:
    return getattr(settings, 'SUMSUB_SECRET_KEY', '') or ''


def _level_name() -> str:
    return getattr(settings, 'SUMSUB_LEVEL_NAME', '') or 'basic-kyc-level'


def _send_personal_data() -> bool:
    return bool(getattr(settings, 'SUMSUB_SEND_PERSONAL_DATA', False))


def _redirect_sign_key() -> str:
    return getattr(settings, 'SUMSUB_REDIRECT_SIGN_KEY', '') or ''


def _customization_name() -> str:
    return (getattr(settings, 'SUMSUB_CUSTOMIZATION_NAME', '') or '').strip()


def _sign(*, ts: str, method: str, path_with_query: str, body: bytes) -> str:
    secret = _secret_key().encode('utf-8')
    payload = ts.encode('utf-8') + method.upper().encode('utf-8') + path_with_query.encode(
        'utf-8'
    ) + body
    return hmac.new(secret, payload, hashlib.sha256).hexdigest()


def _auth_headers(*, method: str, path_with_query: str, body: bytes) -> dict[str, str]:
    token = _app_token()
    secret = _secret_key()
    if not token or not secret:
        raise SumsubError('Sumsub is not configured (missing app token or secret).')
    ts = str(int(time.time()))
    sig = _sign(ts=ts, method=method, path_with_query=path_with_query, body=body)
    return {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-App-Token': token,
        'X-App-Access-Ts': ts,
        'X-App-Access-Sig': sig,
    }


def _request(
    method: str,
    path: str,
    *,
    body: dict[str, Any] | None = None,
    query: dict[str, str] | None = None,
) -> dict[str, Any]:
    path_with_query = path
    if query:
        path_with_query = f'{path}?{urlencode(query)}'

    raw_body = b''
    if body is not None:
        raw_body = json.dumps(body, separators=(',', ':')).encode('utf-8')

    headers = _auth_headers(method=method, path_with_query=path_with_query, body=raw_body)
    url = f'{_base_url()}{path_with_query}'
    logger.info(
        'Sumsub request %s %s body=%s',
        method.upper(),
        path_with_query,
        raw_body.decode('utf-8') if raw_body else '',
    )
    req = urllib.request.Request(
        url,
        data=raw_body if raw_body else None,
        headers=headers,
        method=method.upper(),
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            raw = resp.read().decode('utf-8')
            logger.info(
                'Sumsub response %s %s body=%s',
                resp.status,
                path_with_query,
                raw[:2000] if raw else '',
            )
            if not raw:
                return {}
            return json.loads(raw)
    except urllib.error.HTTPError as exc:
        err_body = exc.read().decode('utf-8', errors='replace')
        logger.warning(
            'Sumsub HTTP %s %s request_body=%s response=%s',
            exc.code,
            path_with_query,
            raw_body.decode('utf-8') if raw_body else '',
            err_body,
        )
        raise SumsubError(f'Sumsub API error {exc.code}: {err_body}') from exc
    except urllib.error.URLError as exc:
        logger.warning(
            'Sumsub network error %s request_body=%s: %s',
            path_with_query,
            raw_body.decode('utf-8') if raw_body else '',
            exc,
        )
        raise SumsubError(f'Sumsub network error: {exc}') from exc


def _request_bytes(
    method: str,
    path: str,
) -> tuple[bytes, str]:
    """Signed GET returning (raw_bytes, content_type)."""
    path_with_query = path
    headers = _auth_headers(method=method, path_with_query=path_with_query, body=b'')
    headers['Accept'] = '*/*'
    url = f'{_base_url()}{path_with_query}'
    logger.info('Sumsub request %s %s (binary)', method.upper(), path_with_query)
    req = urllib.request.Request(url, headers=headers, method=method.upper())
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            data = resp.read()
            content_type = resp.headers.get('Content-Type', 'application/octet-stream')
            logger.info(
                'Sumsub response %s %s bytes=%s content_type=%s',
                resp.status,
                path_with_query,
                len(data),
                content_type,
            )
            return data, content_type
    except urllib.error.HTTPError as exc:
        err_body = exc.read().decode('utf-8', errors='replace')
        logger.warning(
            'Sumsub HTTP %s %s response=%s',
            exc.code,
            path_with_query,
            err_body,
        )
        raise SumsubError(f'Sumsub API error {exc.code}: {err_body}') from exc
    except urllib.error.URLError as exc:
        logger.warning('Sumsub network error %s: %s', path_with_query, exc)
        raise SumsubError(f'Sumsub network error: {exc}') from exc


def create_access_token(
    *,
    user,
    level_name: str | None = None,
) -> dict[str, Any]:
    """POST /resources/accessTokens/sdk — token for Flutter Idensic SDK."""
    level = level_name or _level_name()
    return _request(
        'POST',
        '/resources/accessTokens/sdk',
        body={
            'userId': external_user_id_for(user),
            'levelName': level,
        },
    )


def _redirect_query_param_names(*urls: str) -> list[str]:
    """Collect unique query param names from redirect URLs (Sumsub allowedQueryParams)."""
    names: list[str] = []
    seen: set[str] = set()
    for url in urls:
        if '?' not in url:
            continue
        query = url.split('?', 1)[1]
        for part in query.split('&'):
            if not part:
                continue
            key = part.split('=', 1)[0].strip()
            if key and key not in seen:
                seen.add(key)
                names.append(key)
    return names


def create_websdk_link(
    *,
    user,
    level_name: str | None = None,
    success_url: str,
    reject_url: str,
    ttl_in_secs: int = 1800,
    lang: str | None = None,
) -> dict[str, Any]:
    """POST /resources/sdkIntegrations/levels/-/websdkLink with redirect URLs."""
    level = level_name or _level_name()
    query: dict[str, str] = {}
    if lang:
        query['lang'] = lang
    customization = _customization_name()
    if customization:
        query['customizationName'] = customization
    redirect: dict[str, Any] = {
        'successUrl': success_url,
        'rejectUrl': reject_url,
    }
    sign_key = _redirect_sign_key()
    if sign_key:
        redirect['signKey'] = sign_key
    # Sumsub rejects successUrl/rejectUrl with query strings unless listed here.
    # Always allow jwt/sbx/status which Sumsub appends on redirect.
    allowed = _redirect_query_param_names(success_url, reject_url)
    for extra in ('status', 'jwt', 'sbx'):
        if extra not in allowed:
            allowed.append(extra)
    redirect['allowedQueryParams'] = allowed
    body: dict[str, Any] = {
        'levelName': level,
        'userId': external_user_id_for(user),
        'ttlInSecs': ttl_in_secs,
        'redirect': redirect,
    }
    if _send_personal_data():
        identifiers: dict[str, str] = {}
        if user.email:
            identifiers['email'] = user.email
        if getattr(user, 'phone', None):
            identifiers['phone'] = user.phone
        if identifiers:
            body['applicantIdentifiers'] = identifiers
    return _request(
        'POST',
        '/resources/sdkIntegrations/levels/-/websdkLink',
        body=body,
        query=query or None,
    )


def get_applicant_by_external_user_id(external_user_id: str) -> dict[str, Any]:
    """GET /resources/applicants/-;externalUserId={externalUserId}/one"""
    encoded = urllib.parse.quote(str(external_user_id), safe='')
    return _request('GET', f'/resources/applicants/-;externalUserId={encoded}/one')


def list_applicant_document_images(applicant_id: str) -> list[dict[str, Any]]:
    """GET /resources/applicants/{applicantId}/metadata/resources"""
    encoded = urllib.parse.quote(str(applicant_id), safe='')
    data = _request('GET', f'/resources/applicants/{encoded}/metadata/resources')
    if isinstance(data, list):
        return data
    if isinstance(data, dict):
        items = data.get('items') or data.get('resources') or data.get('list')
        if isinstance(items, list):
            return items
    return []


def download_inspection_image(
    *,
    inspection_id: str,
    image_id: str,
) -> tuple[bytes, str]:
    """GET /resources/inspections/{inspectionId}/resources/{imageId}"""
    insp = urllib.parse.quote(str(inspection_id), safe='')
    img = urllib.parse.quote(str(image_id), safe='')
    return _request_bytes('GET', f'/resources/inspections/{insp}/resources/{img}')
