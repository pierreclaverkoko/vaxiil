"""Booking lifecycle emails + in-app notifications."""

from __future__ import annotations

from django.utils.translation import gettext as _

from src.apps.notifications.models import Notification
from src.apps.notifications.services import notify_email_only, notify_user
from src.apps.organizations.models import OrganizationMembership
from src.apps.payments.services.refunds import booking_is_paid


def _booking_ref(booking) -> str:
    return str(booking.pk)[:8]


def notify_booking_received(booking) -> None:
    org = booking.organization
    service_name = booking.service.name
    title = _('New booking received')
    body = _(
        'You received a new booking for %(service)s (ref %(ref)s).\n'
        'Open the business bookings inbox to review it.'
    ) % {'service': service_name, 'ref': _booking_ref(booking)}

    if org.email:
        notify_email_only(email=org.email, title=str(title), body=str(body))

    staff_roles = {
        OrganizationMembership.OrganizationMemberRole.OWNER,
        OrganizationMembership.OrganizationMemberRole.ADMIN,
        OrganizationMembership.OrganizationMemberRole.MANAGER,
    }
    memberships = OrganizationMembership.objects.filter(
        organization_id=org.pk,
        role__in=staff_roles,
    ).select_related('user')
    for m in memberships:
        notify_user(
            user=m.user,
            kind=Notification.Kind.BOOKING_RECEIVED,
            title=str(title),
            body=str(body),
            booking=booking,
            send_email=bool(m.user.email and m.user.email.lower() != (org.email or '').lower()),
        )


def notify_booking_confirmed(booking) -> None:
    title = _('Your booking is confirmed')
    body = _(
        'Your booking for %(service)s (ref %(ref)s) has been confirmed by the business.'
    ) % {'service': booking.service.name, 'ref': _booking_ref(booking)}
    notify_user(
        user=booking.user,
        kind=Notification.Kind.BOOKING_CONFIRMED,
        title=str(title),
        body=str(body),
        booking=booking,
    )


def notify_reschedule_proposed(booking, *, proposed_by_client: bool) -> None:
    title = _('Reschedule proposed')
    if proposed_by_client:
        body = _(
            'The client proposed a new time for booking %(service)s (ref %(ref)s). '
            'Please accept or decline the proposal.'
        ) % {'service': booking.service.name, 'ref': _booking_ref(booking)}
        if booking.organization.email:
            notify_email_only(
                email=booking.organization.email,
                title=str(title),
                body=str(body),
            )
        staff_roles = {
            OrganizationMembership.OrganizationMemberRole.OWNER,
            OrganizationMembership.OrganizationMemberRole.ADMIN,
            OrganizationMembership.OrganizationMemberRole.MANAGER,
            OrganizationMembership.OrganizationMemberRole.STAFF,
        }
        for m in OrganizationMembership.objects.filter(
            organization_id=booking.organization_id,
            role__in=staff_roles,
        ).select_related('user'):
            notify_user(
                user=m.user,
                kind=Notification.Kind.RESCHEDULE_PROPOSED,
                title=str(title),
                body=str(body),
                booking=booking,
                send_email=False,
            )
        return

    if booking_is_paid(booking):
        body = _(
            'The business proposed a new time for your booking %(service)s (ref %(ref)s). '
            'Please accept or decline the proposal.'
        ) % {'service': booking.service.name, 'ref': _booking_ref(booking)}
    else:
        body = _(
            'The business proposed a new time for your booking %(service)s (ref %(ref)s). '
            'Please pay to confirm the new time, or decline the proposal.'
        ) % {'service': booking.service.name, 'ref': _booking_ref(booking)}
    notify_user(
        user=booking.user,
        kind=Notification.Kind.RESCHEDULE_PROPOSED,
        title=str(title),
        body=str(body),
        booking=booking,
    )


def notify_reschedule_accepted(booking, *, notify_user_obj) -> None:
    title = _('Reschedule accepted')
    body = _(
        'The proposed new time for booking %(service)s (ref %(ref)s) was accepted.'
    ) % {'service': booking.service.name, 'ref': _booking_ref(booking)}
    notify_user(
        user=notify_user_obj,
        kind=Notification.Kind.RESCHEDULE_ACCEPTED,
        title=str(title),
        body=str(body),
        booking=booking,
    )


def notify_booking_cancelled(booking, *, notify_user_obj, reason: str = '') -> None:
    title = _('Booking cancelled')
    if reason:
        body = _(
            'Booking %(service)s (ref %(ref)s) was cancelled. Reason: %(reason)s'
        ) % {
            'service': booking.service.name,
            'ref': _booking_ref(booking),
            'reason': reason,
        }
    else:
        body = _('Booking %(service)s (ref %(ref)s) was cancelled.') % {
            'service': booking.service.name,
            'ref': _booking_ref(booking),
        }
    notify_user(
        user=notify_user_obj,
        kind=Notification.Kind.BOOKING_CANCELLED,
        title=str(title),
        body=str(body),
        booking=booking,
    )


def notify_reschedule_declined(booking, *, notify_user_obj, refunded: bool) -> None:
    title = _('Reschedule declined')
    if refunded:
        body = _(
            'The reschedule for booking %(service)s (ref %(ref)s) was declined. '
            'Any payment was credited back to your store credit.'
        ) % {'service': booking.service.name, 'ref': _booking_ref(booking)}
    else:
        body = _(
            'The reschedule for booking %(service)s (ref %(ref)s) was declined. '
            'The booking has been cancelled.'
        ) % {'service': booking.service.name, 'ref': _booking_ref(booking)}
    notify_user(
        user=notify_user_obj,
        kind=Notification.Kind.RESCHEDULE_DECLINED,
        title=str(title),
        body=str(body),
        booking=booking,
    )
