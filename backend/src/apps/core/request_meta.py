"""Client IP, user-agent, optional GPS, and AuditEvent creation."""

from __future__ import annotations

from decimal import Decimal, InvalidOperation
from typing import Any

from src.apps.core.audit import AuditEvent

# Stable action codes for AuditEvent.action
PAYMENT_LINK_CREATE = 'payment.link_create'
PAYMENT_WALLET_APPLY = 'payment.wallet_apply'
PAYMENT_TOPUP_CREATE = 'payment.topup_create'
BOOKING_CANCEL = 'booking.cancel'
BOOKING_CONFIRM = 'booking.confirm'
BOOKING_REJECT = 'booking.reject'
BOOKING_COMPLETE = 'booking.complete'
BOOKING_RESCHEDULE = 'booking.reschedule'
BOOKING_RESCHEDULE_ACCEPT = 'booking.reschedule_accept'
BOOKING_RESCHEDULE_DECLINE = 'booking.reschedule_decline'
LEGAL_ACCEPT = 'legal.accept'
CANCELLATION_REQUEST_CREATED = 'cancellation.request_created'
CANCELLATION_REQUEST_APPROVED = 'cancellation.request_approved'
CANCELLATION_REQUEST_REJECTED = 'cancellation.request_rejected'
CANCELLATION_REFUND_PROCESSED = 'cancellation.refund_processed'


def client_ip_from_request(request) -> str | None:
    """Return the client IP from X-Forwarded-For or REMOTE_ADDR."""
    if request is None:
        return None
    ip = request.META.get('HTTP_X_FORWARDED_FOR', '').split(',')[0].strip()
    if not ip:
        ip = request.META.get('REMOTE_ADDR')
    return ip or None


def client_user_agent(request) -> str:
    if request is None:
        return ''
    return (request.META.get('HTTP_USER_AGENT') or '')[:512]


def parse_client_location(data: Any) -> dict[str, Decimal | float | None]:
    """Extract optional GPS fields from a request body mapping.

    Incomplete or invalid pairs are ignored (all location fields None).
    """
    empty: dict[str, Decimal | float | None] = {
        'latitude': None,
        'longitude': None,
        'accuracy_m': None,
    }
    if not isinstance(data, dict):
        return empty

    lat_raw = data.get('client_latitude')
    lng_raw = data.get('client_longitude')
    if lat_raw is None or lat_raw == '' or lng_raw is None or lng_raw == '':
        return empty

    try:
        lat = Decimal(str(lat_raw))
        lng = Decimal(str(lng_raw))
    except (InvalidOperation, TypeError, ValueError):
        return empty

    if not (Decimal('-90') <= lat <= Decimal('90')):
        return empty
    if not (Decimal('-180') <= lng <= Decimal('180')):
        return empty

    accuracy: float | None = None
    acc_raw = data.get('client_location_accuracy_m')
    if acc_raw is not None and acc_raw != '':
        try:
            accuracy = float(acc_raw)
            if accuracy < 0:
                accuracy = None
        except (TypeError, ValueError):
            accuracy = None

    return {
        'latitude': lat.quantize(Decimal('0.000001')),
        'longitude': lng.quantize(Decimal('0.000001')),
        'accuracy_m': accuracy,
    }


def create_audit_event(
    request,
    *,
    user,
    action: str,
    latitude: Decimal | None = None,
    longitude: Decimal | None = None,
    accuracy_m: float | None = None,
) -> AuditEvent:
    """Create an append-only AuditEvent from request meta + optional GPS."""
    if latitude is None and longitude is None and request is not None:
        data = getattr(request, 'data', None)
        loc = parse_client_location(data if data is not None else {})
        latitude = loc['latitude']  # type: ignore[assignment]
        longitude = loc['longitude']  # type: ignore[assignment]
        accuracy_m = loc['accuracy_m']  # type: ignore[assignment]

    return AuditEvent.objects.create(
        user=user if getattr(user, 'is_authenticated', False) else None,
        action=action,
        ip_address=client_ip_from_request(request),
        user_agent=client_user_agent(request),
        latitude=latitude,
        longitude=longitude,
        location_accuracy_m=accuracy_m,
    )
