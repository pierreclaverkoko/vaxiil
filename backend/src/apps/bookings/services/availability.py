from __future__ import annotations

from datetime import date, datetime, time, timedelta
from typing import Any

from django.utils import timezone
from django.utils.formats import date_format
from django.utils.translation import gettext as _
from rest_framework.exceptions import ValidationError

from src.apps.bookings.models import AvailabilityException, Booking, BookingTimeSlot, BusinessHours
from src.apps.organizations.models import OrganizationSettings


class AvailabilityService:
    """Validate booking time slots against scheduling rules and active bookings."""

    _BLOCKING_STATUSES = (
        Booking.BookingStatus.DRAFT,
        Booking.BookingStatus.REQUESTED,
        Booking.BookingStatus.CONFIRMED,
        Booking.BookingStatus.IN_PROGRESS,
        Booking.BookingStatus.RESCHEDULED,
    )

    @classmethod
    def validate_slots(
        cls,
        *,
        service,
        practitioner,
        slots,
        booking: Booking | None = None,
    ) -> None:
        """Raise a structured validation error when one or more slots are unavailable."""
        for slot in slots:
            start_time = slot["start_time"]
            end_time = slot["end_time"]
            if end_time <= start_time:
                raise ValidationError({"time_slots": [_("Each time slot must end after it starts.")]})
            cls._validate_booking_window(service.organization, start_time)
            cls._validate_within_open_hours(service, start_time, end_time)
            conflicts = cls.find_overlapping_slots(
                service=service,
                practitioner=practitioner,
                start_time=start_time,
                end_time=end_time,
                exclude_booking=booking,
            )
            if conflicts:
                raise ValidationError(
                    {
                        "time_slots": [cls._conflict_message(conflicts[0])],
                        "conflicts": conflicts,
                    }
                )

    @classmethod
    def list_open_slots(
        cls,
        *,
        service,
        day: date,
        duration_minutes: int,
        exclude_booking: Booking | None = None,
    ) -> list[dict[str, datetime]]:
        """Return open start/end datetimes for a service on a calendar day."""
        if duration_minutes <= 0:
            raise ValidationError({'duration': [_('Duration must be positive.')]})

        window = cls._hours_window_for_day(service, day)
        if window is None:
            return []

        open_t, close_t = window
        tz = timezone.get_current_timezone()
        day_start = timezone.make_aware(datetime.combine(day, open_t), tz)
        day_end = timezone.make_aware(datetime.combine(day, close_t), tz)
        if day_end <= day_start:
            return []

        step = timedelta(minutes=duration_minutes)
        now = timezone.now()
        earliest, latest = cls._booking_window_bounds(service.organization, now)

        slots: list[dict[str, datetime]] = []
        cursor = day_start
        while cursor + step <= day_end:
            slot_end = cursor + step
            if earliest is not None and cursor < earliest:
                cursor += step
                continue
            if latest is not None and cursor > latest:
                break
            conflicts = cls.find_overlapping_slots(
                service=service,
                practitioner=None,
                start_time=cursor,
                end_time=slot_end,
                exclude_booking=exclude_booking,
            )
            if not conflicts:
                slots.append({'start_time': cursor, 'end_time': slot_end})
            cursor += step
        return slots

    @classmethod
    def find_overlapping_slots(
        cls,
        *,
        service,
        practitioner,
        start_time,
        end_time,
        exclude_booking: Booking | None = None,
    ) -> list[dict]:
        """Return conflicting bookings that overlap the given window."""
        bookings = Booking.objects.filter(
            service=service,
            status__in=cls._BLOCKING_STATUSES,
            deleted_at__isnull=True,
        )
        if practitioner is not None:
            bookings = bookings.filter(practitioner=practitioner)
        if exclude_booking is not None:
            bookings = bookings.exclude(pk=exclude_booking.pk)

        qs = (
            BookingTimeSlot.objects.filter(
                booking__in=bookings,
                deleted_at__isnull=True,
                start_time__lt=end_time,
                end_time__gt=start_time,
            )
            .select_related('booking')
            .order_by('start_time')
        )
        results: list[dict] = []
        for slot in qs[:5]:
            results.append(
                {
                    'booking_id': str(slot.booking_id),
                    'reference': str(slot.booking_id)[:8],
                    'start_time': slot.start_time.isoformat(),
                    'end_time': slot.end_time.isoformat(),
                }
            )
        return results

    @classmethod
    def _validate_within_open_hours(cls, service, start_time, end_time) -> None:
        local_start = timezone.localtime(start_time)
        local_end = timezone.localtime(end_time)
        if local_start.date() != local_end.date():
            raise ValidationError(
                {'time_slots': [_('Time slots must stay within a single day.')]}
            )
        window = cls._hours_window_for_day(service, local_start.date())
        if window is None:
            raise ValidationError(
                {'time_slots': [_('This date is outside business hours.')]}
            )
        open_t, close_t = window
        if local_start.time() < open_t or local_end.time() > close_t:
            raise ValidationError(
                {'time_slots': [_('This time is outside business hours.')]}
            )

    @classmethod
    def _hours_window_for_day(cls, service, day: date) -> tuple[time, time] | None:
        org = service.organization
        exception = (
            AvailabilityException.objects.filter(
                organization=org,
                date=day,
                deleted_at__isnull=True,
            )
            .order_by('id')
            .first()
        )
        if exception is not None:
            if exception.is_closed:
                return None
            alt = exception.alternate_hours or {}
            open_raw = alt.get('open_time') or alt.get('open')
            close_raw = alt.get('close_time') or alt.get('close')
            open_t = cls._parse_time(open_raw)
            close_t = cls._parse_time(close_raw)
            if open_t and close_t:
                return open_t, close_t
            return None

        hours = (
            BusinessHours.objects.filter(
                organization=org,
                day_of_week=day.weekday(),
                deleted_at__isnull=True,
            )
            .order_by('id')
            .first()
        )
        if hours is not None:
            if hours.is_closed:
                return None
            return hours.open_time, hours.close_time

        start = getattr(service, 'available_start_time', None) or time(9, 0)
        end = getattr(service, 'available_end_time', None) or time(17, 0)
        return start, end

    @staticmethod
    def _parse_time(raw: Any) -> time | None:
        if isinstance(raw, time):
            return raw
        if not isinstance(raw, str) or not raw:
            return None
        for fmt in ('%H:%M:%S', '%H:%M'):
            try:
                return datetime.strptime(raw, fmt).time()
            except ValueError:
                continue
        return None

    @staticmethod
    def _conflict_message(conflict: dict) -> str:
        try:
            from django.utils.dateparse import parse_datetime

            start = parse_datetime(conflict['start_time'])
            when = date_format(timezone.localtime(start), 'DATETIME_FORMAT') if start else conflict['start_time']
        except (TypeError, ValueError, KeyError):
            when = conflict.get('start_time', '')
        return _(
            'This time slot overlaps booking %(ref)s (%(when)s).'
        ) % {'ref': conflict.get('reference', ''), 'when': when}

    @staticmethod
    def _booking_window_bounds(organization, now: datetime) -> tuple[datetime | None, datetime | None]:
        try:
            settings = organization.settings
        except OrganizationSettings.DoesNotExist:
            return None, None
        earliest = now + timedelta(hours=settings.minimum_booking_hours_notice)
        latest = now + timedelta(days=settings.maximum_booking_days_ahead)
        return earliest, latest

    @staticmethod
    def _validate_booking_window(organization, start_time) -> None:
        try:
            settings = organization.settings
        except OrganizationSettings.DoesNotExist:
            return

        now = timezone.now()
        if start_time < now + timedelta(hours=settings.minimum_booking_hours_notice):
            raise ValidationError({"time_slots": [_("This booking does not meet the minimum notice " "period.")]})
        if start_time > now + timedelta(days=settings.maximum_booking_days_ahead):
            raise ValidationError({"time_slots": [_("This booking is beyond the maximum booking window.")]})
