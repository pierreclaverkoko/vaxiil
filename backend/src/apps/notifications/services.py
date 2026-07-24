from __future__ import annotations

from django.utils import timezone
from django.utils.translation import gettext as _

from src.apps.notifications.email import send_templated_mail
from src.apps.notifications.models import Notification


def _send_notification_email(*, recipient: str, title: str, body: str) -> None:
    send_templated_mail(
        to=recipient,
        subject=title,
        template='notification',
        context={
            'eyebrow': _('Notification'),
            'headline': title,
            'greeting': _('Hello,'),
            'body': body,
            'footer_note': _(
                'You are receiving this because of activity on your Vaxiil account.'
            ),
        },
        fail_silently=True,
    )


def notify_user(
    *,
    user,
    kind: str,
    title: str,
    body: str,
    booking=None,
    email: str | None = None,
    send_email: bool = True,
) -> Notification:
    """Persist an in-app notification and optionally email the user."""
    notification = Notification.objects.create(
        user=user,
        kind=kind,
        title=title,
        body=body,
        booking=booking,
    )
    recipient = (email or getattr(user, 'email', '') or '').strip()
    if send_email and recipient:
        _send_notification_email(recipient=recipient, title=title, body=body)
        notification.email_sent_at = timezone.now()
        notification.save(update_fields=['email_sent_at'])
    return notification


def notify_email_only(
    *,
    email: str,
    title: str,
    body: str,
) -> None:
    """Send mail without a user row (e.g. organization contact email)."""
    recipient = (email or '').strip()
    if not recipient:
        return
    _send_notification_email(recipient=recipient, title=title, body=body)
