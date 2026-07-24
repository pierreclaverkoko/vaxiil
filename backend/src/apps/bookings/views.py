from django.db import transaction
from django.db.models import Q
from django.utils import timezone
from django.utils.dateparse import parse_datetime
from django.utils.translation import gettext as _
from rest_framework import permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.response import Response

from src.apps.bookings.access import ORG_BOOKING_ROLES, user_is_org_booking_staff
from src.apps.bookings.location_types import effective_location_types
from src.apps.bookings.models import Booking, BookingRescheduleProposal, BookingTimeSlot
from src.apps.bookings.notify import (
    notify_booking_cancelled,
    notify_booking_confirmed,
    notify_booking_received,
    notify_reschedule_accepted,
    notify_reschedule_declined,
    notify_reschedule_proposed,
)
from src.apps.bookings.serializers import (
    BookingCancelSerializer,
    BookingCreateSerializer,
    BookingRejectSerializer,
    BookingRescheduleSerializer,
    BookingSerializer,
)
from src.apps.bookings.services import AvailabilityService
from src.apps.organizations.models import OrganizationMembership
from src.apps.payments.services.refunds import booking_is_paid, refund_for_booking_cancellation


def _serialize_slot_row(row: dict) -> dict:
    """Normalize slot dict for JSON storage (ISO datetimes)."""
    out = dict(row)
    for key in ('start_time', 'end_time'):
        val = out.get(key)
        if hasattr(val, 'isoformat'):
            out[key] = val.isoformat()
    return out


def _deserialize_slot_rows(rows: list) -> list[dict]:
    slots = []
    for row in rows:
        item = dict(row)
        for key in ('start_time', 'end_time'):
            val = item.get(key)
            if isinstance(val, str):
                parsed = parse_datetime(val)
                if parsed is None:
                    raise ValidationError({'time_slots': _('Invalid datetime in proposed slots.')})
                item[key] = parsed
        slots.append(item)
    return slots


def _pending_proposal(booking: Booking) -> BookingRescheduleProposal | None:
    return (
        booking.reschedule_proposals.filter(
            status=BookingRescheduleProposal.ProposalStatus.PENDING,
            deleted_at__isnull=True,
        )
        .order_by('-created_at')
        .first()
    )


class BookingViewSet(viewsets.ModelViewSet):
    """Create and manage bookings (client + organization staff)."""

    permission_classes = [permissions.IsAuthenticated]
    http_method_names = ['get', 'post', 'head', 'options']

    def get_queryset(self):
        user = self.request.user
        qs = (
            Booking.objects.filter(deleted_at__isnull=True)
            .select_related(
                'service',
                'service__sub_category',
                'service__sub_category__category',
                'organization',
                'practitioner',
                'accepted_currency',
                'accepted_currency__currency',
                'service_variant',
                'user',
            )
            .prefetch_related('time_slots', 'payment_transactions', 'reschedule_proposals')
            .order_by('-created_at')
        )
        org_param = self.request.query_params.get('organization')
        if user.is_staff:
            if org_param:
                qs = qs.filter(organization_id=org_param)
            return qs
        org_ids = OrganizationMembership.objects.filter(user=user).values_list(
            'organization_id', flat=True
        )
        qs = qs.filter(Q(user=user) | Q(organization_id__in=org_ids)).distinct()
        if org_param:
            if not user_is_org_booking_staff(user, org_param):
                return qs.none()
            qs = qs.filter(organization_id=org_param)
        return qs

    def get_serializer_class(self):
        if self.action == 'create':
            return BookingCreateSerializer
        return BookingSerializer

    def perform_create(self, serializer):
        serializer.save()

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        booking = serializer.instance
        notify_booking_received(booking)
        out = BookingSerializer(
            booking,
            context={'request': request},
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
        raise PermissionDenied(_('You cannot access this booking.'))

    def _ensure_org_booking_staff(self, user, booking):
        if user.is_staff or user_is_org_booking_staff(user, booking.organization_id):
            return
        raise PermissionDenied(_('Only organization staff can manage this booking.'))

    def retrieve(self, request, *args, **kwargs):
        booking = self.get_object()
        self._ensure_booking_access(request.user, booking)
        return super().retrieve(request, *args, **kwargs)

    @action(detail=True, methods=['post'], url_path='cancel')
    def cancel(self, request, pk=None):
        booking = self.get_object()
        self._ensure_booking_access(request.user, booking)
        ser = BookingCancelSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        reason = ser.validated_data.get('reason', '')
        is_client = booking.user_id == request.user.id
        is_org = user_is_org_booking_staff(request.user, booking.organization_id) or request.user.is_staff
        paid = booking_is_paid(booking)

        if is_org and not is_client:
            if booking.status not in (
                Booking.BookingStatus.CONFIRMED,
                Booking.BookingStatus.IN_PROGRESS,
            ):
                raise ValidationError(
                    {
                        'detail': _(
                            'Businesses can only cancel accepted (confirmed) bookings. '
                            'Reject unpaid requests, or decline a reschedule proposal.'
                        )
                    }
                )
        elif is_client:
            if booking.status == Booking.BookingStatus.REQUESTED and paid:
                raise ValidationError(
                    {
                        'detail': _(
                            'Paid requests cannot be cancelled by the client. '
                            'Wait for the business decision or decline a reschedule proposal.'
                        )
                    }
                )
            if booking.status not in (
                Booking.BookingStatus.REQUESTED,
                Booking.BookingStatus.CONFIRMED,
                Booking.BookingStatus.IN_PROGRESS,
            ):
                raise ValidationError({'detail': _('This booking cannot be cancelled.')})
        else:
            raise PermissionDenied(_('You cannot cancel this booking.'))

        with transaction.atomic():
            refund = refund_for_booking_cancellation(
                booking,
                reason=reason,
                initiated_by=request.user,
            )
            booking.cancel(reason=reason)
        booking.refresh_from_db()
        if is_org and not is_client:
            notify_booking_cancelled(booking, notify_user_obj=booking.user, reason=reason)
        elif is_client:
            staff_roles = {
                OrganizationMembership.OrganizationMemberRole.OWNER,
                OrganizationMembership.OrganizationMemberRole.ADMIN,
                OrganizationMembership.OrganizationMemberRole.MANAGER,
            }
            for m in OrganizationMembership.objects.filter(
                organization_id=booking.organization_id,
                role__in=staff_roles,
            ).select_related('user'):
                if m.user_id != request.user.id:
                    notify_booking_cancelled(
                        booking, notify_user_obj=m.user, reason=reason
                    )
        out = BookingSerializer(booking, context={'request': request})
        return Response(
            {
                'booking': out.data,
                'refund': {
                    'attempted': refund.attempted,
                    'amount': str(refund.amount) if refund.amount is not None else None,
                    'currency_code': refund.currency_code,
                    'status': refund.status,
                    'transaction_id': refund.transaction_id,
                    'reason': refund.reason,
                    'destination': refund.destination,
                },
            },
            status=status.HTTP_200_OK,
        )

    @action(detail=True, methods=['post'], url_path='confirm')
    def confirm(self, request, pk=None):
        booking = self.get_object()
        self._ensure_org_booking_staff(request.user, booking)
        if booking.status != Booking.BookingStatus.REQUESTED:
            raise ValidationError({'detail': _('Only requested bookings can be confirmed.')})
        if not booking_is_paid(booking):
            raise ValidationError(
                {'detail': _('Payment must be confirmed before accepting this booking.')}
            )
        booking.confirm()
        notify_booking_confirmed(booking)
        out = BookingSerializer(booking, context={'request': request})
        return Response(out.data, status=status.HTTP_200_OK)

    @action(detail=True, methods=['post'], url_path='reject')
    def reject(self, request, pk=None):
        booking = self.get_object()
        self._ensure_org_booking_staff(request.user, booking)
        if booking.status != Booking.BookingStatus.REQUESTED:
            raise ValidationError({'detail': _('Only requested bookings can be rejected.')})
        ser = BookingRejectSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        reason = ser.validated_data['reason']
        with transaction.atomic():
            refund_for_booking_cancellation(
                booking,
                reason=reason,
                initiated_by=request.user,
                full_refund=True,
                idempotency_suffix='reject',
            )
            booking.cancel(reason=reason)
        notify_booking_cancelled(booking, notify_user_obj=booking.user, reason=reason)
        out = BookingSerializer(booking, context={'request': request})
        return Response(out.data, status=status.HTTP_200_OK)

    @action(detail=True, methods=['post'], url_path='complete')
    def complete(self, request, pk=None):
        booking = self.get_object()
        self._ensure_org_booking_staff(request.user, booking)
        if booking.status not in (
            Booking.BookingStatus.CONFIRMED,
            Booking.BookingStatus.IN_PROGRESS,
        ):
            raise ValidationError({'detail': _('Only confirmed bookings can be completed.')})
        booking.complete()
        out = BookingSerializer(booking, context={'request': request})
        return Response(out.data, status=status.HTTP_200_OK)

    @action(detail=True, methods=['post'], url_path='reschedule')
    def reschedule(self, request, pk=None):
        booking = self.get_object()
        self._ensure_booking_access(request.user, booking)
        if booking.status not in (
            Booking.BookingStatus.REQUESTED,
            Booking.BookingStatus.CONFIRMED,
        ):
            raise ValidationError(
                {'detail': _('Only requested or confirmed bookings can be rescheduled.')}
            )
        if _pending_proposal(booking):
            raise ValidationError({'detail': _('A reschedule proposal is already pending.')})

        ser = BookingRescheduleSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        slots_data = ser.validated_data['time_slots']
        if not slots_data:
            raise ValidationError({'time_slots': _('At least one time slot is required.')})

        allowed = set(effective_location_types(booking.service))
        for row in slots_data:
            loc = row.get('location_type') or Booking.LocationType.OFFICE
            if loc not in allowed:
                raise ValidationError(
                    {'time_slots': _('Selected venue type is not accepted for this service.')}
                )

        AvailabilityService.validate_slots(
            service=booking.service,
            practitioner=booking.practitioner,
            slots=slots_data,
            booking=booking,
        )

        is_client = booking.user_id == request.user.id
        proposed_by = (
            BookingRescheduleProposal.ProposedBy.CLIENT
            if is_client
            else BookingRescheduleProposal.ProposedBy.BUSINESS
        )
        if not is_client:
            self._ensure_org_booking_staff(request.user, booking)

        with transaction.atomic():
            proposal = BookingRescheduleProposal.objects.create(
                booking=booking,
                proposed_by=proposed_by,
                proposed_by_user=request.user,
                status=BookingRescheduleProposal.ProposalStatus.PENDING,
                time_slots=[_serialize_slot_row(r) for r in slots_data],
                reason=ser.validated_data.get('reason', ''),
            )
            booking.status = Booking.BookingStatus.RESCHEDULED
            booking.save(update_fields=['status', 'updated_at'])

        notify_reschedule_proposed(booking, proposed_by_client=is_client)
        booking.refresh_from_db()
        out = BookingSerializer(booking, context={'request': request})
        return Response(out.data, status=status.HTTP_200_OK)

    @action(detail=True, methods=['post'], url_path='reschedule/accept')
    def reschedule_accept(self, request, pk=None):
        booking = self.get_object()
        self._ensure_booking_access(request.user, booking)
        if booking.status != Booking.BookingStatus.RESCHEDULED:
            raise ValidationError({'detail': _('This booking has no pending reschedule.')})
        proposal = _pending_proposal(booking)
        if proposal is None:
            raise ValidationError({'detail': _('No pending reschedule proposal.')})

        is_client = booking.user_id == request.user.id
        is_org = user_is_org_booking_staff(request.user, booking.organization_id) or request.user.is_staff
        if proposal.proposed_by == BookingRescheduleProposal.ProposedBy.CLIENT:
            if not is_org:
                raise PermissionDenied(_('Only the business can accept this reschedule.'))
            notify_target = booking.user
        else:
            if not is_client:
                raise PermissionDenied(_('Only the client can accept this reschedule.'))
            notify_target = proposal.proposed_by_user or booking.user

        if not booking_is_paid(booking):
            raise ValidationError(
                {'detail': _('Payment must be confirmed before accepting this booking.')}
            )

        slots_data = _deserialize_slot_rows(proposal.time_slots)
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
            proposal.status = BookingRescheduleProposal.ProposalStatus.ACCEPTED
            proposal.decided_at = timezone.now()
            proposal.decided_by = request.user
            proposal.save(update_fields=['status', 'decided_at', 'decided_by', 'updated_at'])
            booking.confirm()

        if notify_target and notify_target.id != request.user.id:
            notify_reschedule_accepted(booking, notify_user_obj=notify_target)
        # Acceptance confirms the booking — always notify the client.
        notify_booking_confirmed(booking)

        booking.refresh_from_db()
        out = BookingSerializer(booking, context={'request': request})
        return Response(out.data, status=status.HTTP_200_OK)

    @action(detail=True, methods=['post'], url_path='reschedule/decline')
    def reschedule_decline(self, request, pk=None):
        booking = self.get_object()
        self._ensure_booking_access(request.user, booking)
        if booking.status != Booking.BookingStatus.RESCHEDULED:
            raise ValidationError({'detail': _('This booking has no pending reschedule.')})
        proposal = _pending_proposal(booking)
        if proposal is None:
            raise ValidationError({'detail': _('No pending reschedule proposal.')})

        is_client = booking.user_id == request.user.id
        is_org = user_is_org_booking_staff(request.user, booking.organization_id) or request.user.is_staff
        if proposal.proposed_by == BookingRescheduleProposal.ProposedBy.CLIENT:
            if not is_org:
                raise PermissionDenied(_('Only the business can decline this reschedule.'))
            notify_target = booking.user
        else:
            if not is_client:
                raise PermissionDenied(_('Only the client can decline this reschedule.'))
            notify_target = proposal.proposed_by_user
            if notify_target is None:
                # Fall back to org owners via booking user notification only.
                notify_target = booking.user

        paid = booking_is_paid(booking)
        reason = _('Reschedule declined')
        with transaction.atomic():
            refund = refund_for_booking_cancellation(
                booking,
                reason=str(reason),
                initiated_by=request.user,
                full_refund=True,
                idempotency_suffix=f'reschedule-{proposal.pk}',
            )
            proposal.status = BookingRescheduleProposal.ProposalStatus.DECLINED
            proposal.decided_at = timezone.now()
            proposal.decided_by = request.user
            proposal.save(update_fields=['status', 'decided_at', 'decided_by', 'updated_at'])
            booking.cancel(reason=str(reason))

        if notify_target and notify_target.id != request.user.id:
            notify_reschedule_declined(
                booking,
                notify_user_obj=notify_target,
                refunded=bool(refund.attempted),
            )
        elif paid and is_org:
            notify_reschedule_declined(
                booking,
                notify_user_obj=booking.user,
                refunded=True,
            )

        booking.refresh_from_db()
        out = BookingSerializer(booking, context={'request': request})
        return Response(out.data, status=status.HTTP_200_OK)
