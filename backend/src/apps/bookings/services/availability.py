from __future__ import annotations

from datetime import timedelta

from django.utils import timezone
from django.utils.translation import gettext_lazy as _
from rest_framework.exceptions import ValidationError

from src.apps.bookings.models import Booking, BookingTimeSlot
from src.apps.organizations.models import OrganizationSettings


class AvailabilityService:
    """Validate booking time slots against scheduling rules and active bookings."""

    _BLOCKING_STATUSES = (
        Booking.BookingStatus.DRAFT,
        Booking.BookingStatus.REQUESTED,
        Booking.BookingStatus.CONFIRMED,
        Booking.BookingStatus.IN_PROGRESS,
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
            if cls._overlaps(
                service=service,
                practitioner=practitioner,
                start_time=start_time,
                end_time=end_time,
                exclude_booking=booking,
            ):
                raise ValidationError({"time_slots": [_("This time slot overlaps an existing booking.")]})

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

    @classmethod
    def _overlaps(
        cls,
        *,
        service,
        practitioner,
        start_time,
        end_time,
        exclude_booking: Booking | None,
    ) -> bool:
        bookings = Booking.objects.filter(
            service=service,
            status__in=cls._BLOCKING_STATUSES,
            deleted_at__isnull=True,
        )
        if practitioner is not None:
            bookings = bookings.filter(practitioner=practitioner)
        if exclude_booking is not None:
            bookings = bookings.exclude(pk=exclude_booking.pk)

        return BookingTimeSlot.objects.filter(
            booking__in=bookings,
            deleted_at__isnull=True,
            start_time__lt=end_time,
            end_time__gt=start_time,
        ).exists()
