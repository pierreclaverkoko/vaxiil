from django.db.models import Q
from rest_framework import permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied
from rest_framework.response import Response

from src.apps.bookings.models import Booking
from src.apps.bookings.serializers import (
    BookingCancelSerializer,
    BookingCreateSerializer,
    BookingSerializer,
)
from src.apps.organizations.models import OrganizationMembership

_ORG_BOOKING_ROLES = frozenset({
    OrganizationMembership.OrganizationMemberRole.OWNER,
    OrganizationMembership.OrganizationMemberRole.ADMIN,
    OrganizationMembership.OrganizationMemberRole.MANAGER,
    OrganizationMembership.OrganizationMemberRole.STAFF,
})


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
            .prefetch_related('time_slots')
            .order_by('-created_at')
        )
        if user.is_staff:
            return qs
        org_ids = OrganizationMembership.objects.filter(user=user).values_list(
            'organization_id', flat=True
        )
        return qs.filter(Q(user=user) | Q(organization_id__in=org_ids)).distinct()

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
        out = BookingSerializer(
            serializer.instance,
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
        if m and m.role in _ORG_BOOKING_ROLES:
            return
        raise PermissionDenied('You cannot access this booking.')

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
        booking.cancel(reason=ser.validated_data.get('reason', ''))
        out = BookingSerializer(booking, context={'request': request})
        return Response(out.data, status=status.HTTP_200_OK)
