"""Payment lifecycle emails + in-app notifications."""

from __future__ import annotations

from django.conf import settings
from django.utils.translation import gettext as _

from src.apps.notifications.models import Notification
from src.apps.notifications.services import booking_cta, notify_user


def _site_url() -> str:
    return (getattr(settings, 'SITE_URL', None) or 'http://localhost:8000').rstrip('/')


def notify_payment_succeeded(txn) -> None:
    """Email + inbox when a booking payment or wallet top-up succeeds."""
    user = txn.user
    if user is None:
        return

    amount = txn.amount
    currency = getattr(getattr(txn, 'currency', None), 'code', '') or ''
    amount_label = f'{amount} {currency}'.strip()

    if txn.booking_id:
        booking = txn.booking
        title = _('Payment received')
        body = _(
            'We received your payment of %(amount)s for booking %(service)s (ref %(ref)s).'
        ) % {
            'amount': amount_label,
            'service': booking.service.name,
            'ref': str(booking.pk)[:8],
        }
        cta_url, cta_label = booking_cta(booking)
        notify_user(
            user=user,
            kind=Notification.Kind.PAYMENT_RECEIVED,
            title=str(title),
            body=str(body),
            booking=booking,
            cta_url=cta_url,
            cta_label=cta_label,
        )
        return

    title = _('Store credit topped up')
    body = _('Your Vaxiil store credit was topped up by %(amount)s.') % {
        'amount': amount_label,
    }
    notify_user(
        user=user,
        kind=Notification.Kind.WALLET_TOPPED_UP,
        title=str(title),
        body=str(body),
        cta_url=f'{_site_url()}/profile',
        cta_label=str(_('View wallet')),
    )
