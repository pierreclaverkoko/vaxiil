"""Mark email verified and send the one-time welcome message."""

from __future__ import annotations

from django.conf import settings
from django.utils import timezone
from django.utils.translation import gettext as _

from src.apps.notifications.email import send_templated_mail


def _site_url() -> str:
    return (getattr(settings, 'SITE_URL', None) or 'http://localhost:8000').rstrip('/')


def send_welcome_email_once(user) -> bool:
    """Send welcome mail at most once. Returns True if sent."""
    if getattr(user, 'welcome_email_sent_at', None):
        return False
    email = (getattr(user, 'email', '') or '').strip()
    if not email:
        return False

    site = _site_url()
    first = (getattr(user, 'first_name', '') or '').strip()
    greeting = _('Hello %(name)s,') % {'name': first} if first else _('Hello,')

    send_templated_mail(
        to=email,
        subject=str(_('Welcome to Vaxiil')),
        template='welcome',
        context={
            'eyebrow': _('Welcome'),
            'headline': _('Your wellness journey starts here'),
            'lede': _(
                'Discover trusted wellness providers, book with confidence, '
                'and stay in control of your privacy.'
            ),
            'greeting': greeting,
            'body': _(
                'Thanks for joining Vaxiil. Here are a few quick ways to get started.'
            ),
            'cta_url': f'{site}/discover',
            'cta_label': _('Open Vaxiil'),
            'tip_title': _('Discover services'),
            'tip_body': _('Browse massage, therapy, and space rentals near you.'),
            'tip_url': f'{site}/discover',
            'pick_title': _('Your bookings'),
            'pick_body': _('Track upcoming appointments and payment status in one place.'),
            'pick_url': f'{site}/bookings',
            'privacy_title': _('Privacy controls'),
            'privacy_body': _(
                'Review Trust Alias and visibility settings whenever you like.'
            ),
            'privacy_action_url': f'{site}/profile',
            'footer_note': _(
                'You are receiving this because you verified your email on Vaxiil.'
            ),
        },
        fail_silently=True,
    )
    user.welcome_email_sent_at = timezone.now()
    user.save(update_fields=['welcome_email_sent_at'])
    return True


def mark_email_verified(user, *, send_welcome: bool = True) -> bool:
    """Set email_verified_at if missing. Returns True when newly verified."""
    if getattr(user, 'email_verified_at', None):
        return False
    user.email_verified_at = timezone.now()
    user.save(update_fields=['email_verified_at'])
    if send_welcome:
        send_welcome_email_once(user)
    return True
