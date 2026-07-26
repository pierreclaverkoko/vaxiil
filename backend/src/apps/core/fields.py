"""Shared DRF serializer fields."""

from typing import Any

from django.utils.translation import gettext_lazy as _
from rest_framework import serializers

from src.apps.core.request_meta import client_ip_from_request
from src.apps.core.turnstile import verify_turnstile_token


class ChoiceValueField(serializers.ChoiceField):
    """Accept a plain choice code or the API's structured `{value, title, css}` object."""

    def to_internal_value(self, data):
        if isinstance(data, dict):
            data = data.get('value')
        if data in ('', None) and self.allow_null:
            return None
        return super().to_internal_value(data)


def choice_enum_dict(instance: Any, field_name: str) -> dict[str, Any] | None:
    """Build `{value, title, css}` for a model choice field (ChoiceEnumField shape)."""
    field_value = getattr(instance, field_name, None)
    if field_value in (None, '', 'None'):
        return None
    display_fn = getattr(instance, f'get_{field_name}_display', None)
    css_fn = getattr(instance, f'get_{field_name}_css', None)
    if not display_fn:
        return {'value': field_value, 'title': str(field_value), 'css': 'default'}
    return {
        'value': field_value,
        'title': display_fn(),
        'css': css_fn() if css_fn else 'default',
    }


class TurnstileField(serializers.CharField):
    """Write-only field that runs Cloudflare Turnstile siteverify on validation."""

    default_error_messages = {
        'turnstile_failed': _('Turnstile verification failed.'),
        'required': _('Turnstile verification is required.'),
        'blank': _('Turnstile verification is required.'),
        'null': _('Turnstile verification is required.'),
    }

    def __init__(self, **kwargs):
        kwargs.setdefault('write_only', True)
        kwargs.setdefault('required', True)
        kwargs.setdefault('allow_blank', False)
        super().__init__(**kwargs)

    def to_internal_value(self, data):
        token = super().to_internal_value(data)
        request = self.context.get('request')
        remote_ip = client_ip_from_request(request)
        if not verify_turnstile_token(token, remote_ip=remote_ip):
            self.fail('turnstile_failed')
        return token
