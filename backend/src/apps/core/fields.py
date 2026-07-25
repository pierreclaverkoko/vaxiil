"""Shared DRF serializer fields."""

from django.utils.translation import gettext_lazy as _
from rest_framework import serializers

from src.apps.core.request_meta import client_ip_from_request
from src.apps.core.turnstile import verify_turnstile_token


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
