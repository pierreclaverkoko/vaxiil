from __future__ import annotations

from django.conf import settings
from django.utils import timezone
from django.utils.translation import gettext as _

from src.apps.notifications.email import send_templated_mail
from src.apps.notifications.models import Notification


def _site_url() -> str:
    return (getattr(settings, 'SITE_URL', None) or 'http://localhost:8000').rstrip('/')


def _send_notification_email(
    *,
    recipient: str,
    title: str,
    body: str,
    cta_url: str | None = None,
    cta_label: str | None = None,
) -> None:
    send_templated_mail(
        to=recipient,
        subject=title,
        template='notification',
        context={
            'eyebrow': _('Notification'),
            'headline': title,
            'greeting': _('Hello,'),
            'body': body,
            'cta_url': cta_url,
            'cta_label': cta_label,
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
    conversation=None,
    message_invite=None,
    organization=None,
    audience: str | None = None,
    email: str | None = None,
    send_email: bool = True,
    cta_url: str | None = None,
    cta_label: str | None = None,
) -> Notification:
    """Persist an in-app notification and optionally email the user."""
    if audience is None:
        if organization is not None:
            audience = Notification.Audience.ORGANIZATION
        else:
            audience = Notification.Audience.PERSONAL
    if (
        audience == Notification.Audience.ORGANIZATION
        and organization is None
        and booking is not None
    ):
        organization = getattr(booking, 'organization', None)

    notification = Notification.objects.create(
        user=user,
        kind=kind,
        audience=audience,
        title=title,
        body=body,
        booking=booking,
        conversation=conversation,
        message_invite=message_invite,
        organization=organization,
    )
    recipient = (email or getattr(user, 'email', '') or '').strip()
    if send_email and recipient:
        _send_notification_email(
            recipient=recipient,
            title=title,
            body=body,
            cta_url=cta_url,
            cta_label=cta_label,
        )
        notification.email_sent_at = timezone.now()
        notification.save(update_fields=['email_sent_at'])
    return notification


def notify_email_only(
    *,
    email: str,
    title: str,
    body: str,
    cta_url: str | None = None,
    cta_label: str | None = None,
) -> None:
    """Send mail without a user row (e.g. organization contact email)."""
    recipient = (email or '').strip()
    if not recipient:
        return
    _send_notification_email(
        recipient=recipient,
        title=title,
        body=body,
        cta_url=cta_url,
        cta_label=cta_label,
    )


def booking_cta(booking) -> tuple[str, str]:
    site = _site_url()
    return f'{site}/bookings/{booking.pk}', str(_('View booking'))


def notifications_for_user(user, *, scope: str | None = None, organization_id=None):
    """Filter notifications by personal / organization / staff scope."""
    qs = Notification.objects.filter(user=user)
    if organization_id:
        from src.apps.bookings.access import user_is_org_booking_staff

        if not user_is_org_booking_staff(user, organization_id):
            from rest_framework.exceptions import PermissionDenied

            raise PermissionDenied(_('Not a member of this organization.'))
        return qs.filter(
            audience=Notification.Audience.ORGANIZATION,
            organization_id=organization_id,
        )
    scope = (scope or Notification.Audience.PERSONAL).strip().lower()
    if scope == Notification.Audience.STAFF:
        if not getattr(user, 'is_staff', False):
            from rest_framework.exceptions import PermissionDenied

            raise PermissionDenied(_('Staff access required.'))
        return qs.filter(audience=Notification.Audience.STAFF)
    return qs.filter(audience=Notification.Audience.PERSONAL)
