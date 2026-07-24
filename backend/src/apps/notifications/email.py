from __future__ import annotations

from django.conf import settings
from django.core.mail import EmailMultiAlternatives
from django.template.loader import render_to_string
from django.utils import translation


def _site_url() -> str:
    return (getattr(settings, 'SITE_URL', None) or 'http://localhost:8000').rstrip('/')


def email_base_context(**extra) -> dict:
    site = _site_url()
    return {
        'site_url': site,
        'logo_url': f'{site}/static/email/logo.png',
        'privacy_url': f'{site}/privacy',
        'terms_url': f'{site}/terms',
        'language': translation.get_language() or 'en',
        **extra,
    }


def send_templated_mail(
    *,
    to: str | list[str],
    subject: str,
    template: str,
    context: dict | None = None,
    fail_silently: bool = False,
) -> int:
    """Send multipart (text + HTML) mail using templates under ``email/``."""
    recipients = [to] if isinstance(to, str) else list(to)
    recipients = [r.strip() for r in recipients if r and r.strip()]
    if not recipients:
        return 0

    ctx = email_base_context(**(context or {}))
    ctx.setdefault('subject', subject)

    text_body = render_to_string(f'email/{template}.txt', ctx)
    html_body = render_to_string(f'email/{template}.html', ctx)
    from_email = getattr(settings, 'DEFAULT_FROM_EMAIL', None) or 'noreply@vaxiil.local'

    message = EmailMultiAlternatives(
        subject=subject,
        body=text_body,
        from_email=from_email,
        to=recipients,
    )
    message.attach_alternative(html_body, 'text/html')
    return message.send(fail_silently=fail_silently)
