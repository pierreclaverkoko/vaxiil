"""PaymentMethod.config helpers for client identifier field UI."""

from __future__ import annotations

from typing import Any

from django.utils.translation import get_language

IDENTIFIER_TYPES = frozenset({'phone', 'email', 'generic'})
DEFAULT_IDENTIFIER_TYPE = 'generic'


def identifier_type_for_method(method) -> str:
    raw = (method.config or {}).get('identifier_type')
    if isinstance(raw, str) and raw.strip().lower() in IDENTIFIER_TYPES:
        return raw.strip().lower()
    # Infer from destination_fields when ops omit identifier_type.
    fields = (method.config or {}).get('destination_fields') or []
    if isinstance(fields, list):
        lowered = {str(f).lower() for f in fields}
        if 'phone_number' in lowered or 'phone' in lowered:
            return 'phone'
        if 'interac_email' in lowered or 'email' in lowered:
            return 'email'
    return DEFAULT_IDENTIFIER_TYPE


def account_placeholder_for_method(method, language: str | None = None) -> str:
    raw = (method.config or {}).get('account_placeholder')
    if isinstance(raw, str) and raw.strip():
        return raw.strip()
    if isinstance(raw, dict):
        lang = (language or get_language() or 'en').split('-')[0].lower()
        for key in (lang, 'en', 'fr'):
            val = raw.get(key)
            if isinstance(val, str) and val.strip():
                return val.strip()
    return ''


def phone_country_codes_for_method(method) -> list[str]:
    raw = (method.config or {}).get('phone_country_codes')
    if not isinstance(raw, list):
        return []
    out: list[str] = []
    for item in raw:
        if isinstance(item, str) and item.strip():
            out.append(item.strip().upper()[:2])
    return out


def identifier_ui_fields(method, language: str | None = None) -> dict[str, Any]:
    return {
        'identifier_type': identifier_type_for_method(method),
        'account_placeholder': account_placeholder_for_method(method, language),
        'phone_country_codes': phone_country_codes_for_method(method),
    }
