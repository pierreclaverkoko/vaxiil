from django.db import transaction
from django.db.models import Q
from django.utils.translation import gettext as _
from rest_framework import permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.response import Response

from src.apps.bookings.access import ORG_BOOKING_ROLES, user_is_org_booking_staff
from src.apps.bookings.models import Booking, BookingTimeSlot
from src.apps.bookings.serializers import (
    BookingCancelSerializer,
    BookingCreateSerializer,
    BookingRejectSerializer,
    BookingRescheduleSerializer,
    BookingSerializer,
)
from src.apps.bookings.services import AvailabilityService
from src.apps.organizations.models import OrganizationMembership
from src.apps.payments.services.refunds import refund_for_booking_cancellation


class BookingViewSet(viewsets.ModelViewSet):
    """Create and manage bookings (client + organization staff)."""

    permission_classes = [permissions.IsAuthenticated]
    http_method_names = ["get", "post", "head", "options"]

    def get_queryset(self):
        user = self.request.user
        qs = (
            Booking.objects.filter(deleted_at__isnull=True)
            .select_related(
                "service",
                "service__sub_category",
                "service__sub_category__category",
                "organization",
                "practitioner",
                "accepted_currency",
                "accepted_currency__currency",
                "service_variant",
                "user",
            )
            .prefetch_related("time_slots", "payment_transactions")
            .order_by("-created_at")
        )
        org_param = self.request.query_params.get("organization")
        if user.is_staff:
            if org_param:
                qs = qs.filter(organization_id=org_param)
            return qs
        org_ids = OrganizationMembership.objects.filter(user=user).values_list("organization_id", flat=True)
        qs = qs.filter(Q(user=user) | Q(organization_id__in=org_ids)).distinct()
        if org_param:
            if not user_is_org_booking_staff(user, org_param):
                return qs.none()
            qs = qs.filter(organization_id=org_param)
        return qs

    def get_serializer_class(self):
        if self.action == "create":
            return BookingCreateSerializer
        return BookingSerializer

    def perform_create(self, serializer):
        serializer.save()

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        out = BookingSerializer(
            serializer.instance,
            context={"request": request},
        )
        return Response(out.data, status=status.HTTP_201_CREATED)

    def _ensure_booking_access(self, user, booking):
        if user.is_staff:
            return
        if booking.user_id == user.id:
            return
        m = OrganizationMembership.objects.filter(
            user=user,
            organization_id=booking.organization_id,
        ).first()
        if m and m.role in ORG_BOOKING_ROLES:
            return
        raise PermissionDenied(_("You cannot access this booking."))

    def _ensure_org_booking_staff(self, user, booking):
        if user.is_staff or user_is_org_booking_staff(user, booking.organization_id):
            return
        raise PermissionDenied(_("Only organization staff can manage this booking."))

    def retrieve(self, request, *args, **kwargs):
        booking = self.get_object()
        self._ensure_booking_access(request.user, booking)
        return super().retrieve(request, *args, **kwargs)

    @action(detail=True, methods=["post"], url_path="cancel")
    def cancel(self, request, pk=None):
        booking = self.get_object()
        self._ensure_booking_access(request.user, booking)
        ser = BookingCancelSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        reason = ser.validated_data.get("reason", "")
        with transaction.atomic():
            refund = refund_for_booking_cancellation(
                booking,
                reason=reason,
                initiated_by=request.user,
            )
            booking.cancel(reason=reason)
        booking.refresh_from_db()
        out = BookingSerializer(booking, context={"request": request})
        return Response(
            {
                "booking": out.data,
                "refund": {
                    "attempted": refund.attempted,
                    "amount": str(refund.amount) if refund.amount is not None else None,
                    "currency_code": refund.currency_code,
                    "status": refund.status,
                    "transaction_id": refund.transaction_id,
                    "reason": refund.reason,
                    "destination": refund.destination,
                },
            },
            status=status.HTTP_200_OK,
        )

    @action(detail=True, methods=["post"], url_path="confirm")
    def confirm(self, request, pk=None):
        booking = self.get_object()
        self._ensure_org_booking_staff(request.user, booking)
        if booking.status != Booking.BookingStatus.REQUESTED:
            raise ValidationError({"detail": _("Only requested bookings can be confirmed.")})
        booking.confirm()
        out = BookingSerializer(booking, context={"request": request})
        return Response(out.data, status=status.HTTP_200_OK)

    @action(detail=True, methods=["post"], url_path="reject")
    def reject(self, request, pk=None):
        booking = self.get_object()
        self._ensure_org_booking_staff(request.user, booking)
        if booking.status != Booking.BookingStatus.REQUESTED:
            raise ValidationError({"detail": _("Only requested bookings can be rejected.")})
        ser = BookingRejectSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        booking.cancel(reason=ser.validated_data["reason"])
        out = BookingSerializer(booking, context={"request": request})
        return Response(out.data, status=status.HTTP_200_OK)

    @action(detail=True, methods=["post"], url_path="complete")
    def complete(self, request, pk=None):
        booking = self.get_object()
        self._ensure_org_booking_staff(request.user, booking)
        if booking.status not in (
            Booking.BookingStatus.CONFIRMED,
            Booking.BookingStatus.IN_PROGRESS,
        ):
            raise ValidationError({"detail": _("Only confirmed bookings can be completed.")})
        booking.complete()
        out = BookingSerializer(booking, context={"request": request})
        return Response(out.data, status=status.HTTP_200_OK)

    @action(detail=True, methods=["post"], url_path="reschedule")
    def reschedule(self, request, pk=None):
        booking = self.get_object()
        self._ensure_booking_access(request.user, booking)
        terminal = {
            Booking.BookingStatus.COMPLETED,
            Booking.BookingStatus.CANCELLED,
            Booking.BookingStatus.NO_SHOW,
        }
        if booking.status in terminal:
            raise ValidationError({"detail": _("This booking cannot be rescheduled.")})
        ser = BookingRescheduleSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        slots_data = ser.validated_data["time_slots"]
        if not slots_data:
            raise ValidationError({"time_slots": _("At least one time slot is required.")})
        AvailabilityService.validate_slots(
            service=booking.service,
            practitioner=booking.practitioner,
            slots=slots_data,
            booking=booking,
        )
        with transaction.atomic():
            for ts in booking.time_slots.filter(deleted_at__isnull=True):
                ts.delete()
            for row in slots_data:
                BookingTimeSlot.objects.create(booking=booking, **row)
            booking.status = Booking.BookingStatus.RESCHEDULED
            booking.save(update_fields=["status", "updated_at"])
        booking.refresh_from_db()
        out = BookingSerializer(booking, context={"request": request})
        return Response(out.data, status=status.HTTP_200_OK)
