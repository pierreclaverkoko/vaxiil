"""Cloudflare Turnstile siteverify helpers."""

from __future__ import annotations

import json
import urllib.error
import urllib.parse
import urllib.request

from django.conf import settings

from src.apps.core.request_meta import client_ip_from_request  # noqa: F401

SITEVERIFY_URL = 'https://challenges.cloudflare.com/turnstile/v0/siteverify'


def verify_turnstile_token(token: str, *, remote_ip: str | None = None) -> bool:
    """POST to Cloudflare siteverify; True only when response.success is True."""
    secret = getattr(settings, 'TURNSTILE_SECRET', '') or ''
    if not secret or not token:
        return False

    body: dict[str, str] = {
        'secret': secret,
        'response': token,
    }
    if remote_ip:
        body['remoteip'] = remote_ip

    data = urllib.parse.urlencode(body).encode('utf-8')
    req = urllib.request.Request(
        SITEVERIFY_URL,
        data=data,
        headers={'Content-Type': 'application/x-www-form-urlencoded'},
        method='POST',
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            payload = json.loads(resp.read().decode('utf-8'))
            print('turnstile payload', payload)
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, ValueError) as e:
        print('turnstile error', e)
        return False

    return payload.get('success') is True
