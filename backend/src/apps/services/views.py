from django.db.models import Prefetch, Q
from django.shortcuts import get_object_or_404
from django.utils.dateparse import parse_date
from django.utils.translation import gettext as _
from rest_framework import permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response

from src.apps.bookings.models import Booking
from src.apps.bookings.services import AvailabilityService
from src.apps.organizations.models import Organization
from src.apps.services.filters import ServiceCatalogFilter
from src.apps.services.models import (
    Service,
    ServiceCategory,
    ServiceFeature,
    ServiceFeatureMapping,
    ServiceSubCategory,
)
from src.apps.services.pagination import CatalogPagination
from src.apps.services.serializers import (
    ServiceCategorySerializer,
    ServiceDetailSerializer,
    ServiceFeatureNestedSerializer,
    ServiceListSerializer,
    ServiceSubCategoryBriefSerializer,
)
from src.apps.users.permissions import IsEmailVerified


class ServiceSubCategoryViewSet(viewsets.ReadOnlyModelViewSet):
    """List active subcategories (for provider service forms)."""

    permission_classes = [permissions.IsAuthenticated, IsEmailVerified]
    serializer_class = ServiceSubCategoryBriefSerializer
    pagination_class = None

    def get_queryset(self):
        return ServiceSubCategory.objects.filter(is_active=True).select_related(
            'category'
        ).order_by('category__sort_order', 'sort_order', 'name')


class ServiceFeatureViewSet(viewsets.ReadOnlyModelViewSet):
    """List global service features (for provider mappings)."""

    permission_classes = [permissions.IsAuthenticated, IsEmailVerified]
    serializer_class = ServiceFeatureNestedSerializer
    pagination_class = None

    def get_queryset(self):
        return ServiceFeature.objects.all().order_by('feature_type', 'name')


class ServiceCategoryViewSet(viewsets.ReadOnlyModelViewSet):
    """List active service categories (icons from `ServiceCategory.icon`)."""

    permission_classes = [permissions.AllowAny]
    serializer_class = ServiceCategorySerializer

    def get_queryset(self):
        return ServiceCategory.objects.filter(is_active=True).order_by(
            'sort_order', 'name'
        )


class ServiceCatalogViewSet(viewsets.ReadOnlyModelViewSet):
    """List active services for the client catalog (search + filters)."""

    permission_classes = [permissions.AllowAny]
    serializer_class = ServiceListSerializer
    pagination_class = CatalogPagination
    filterset_class = ServiceCatalogFilter
    search_fields = ['name', 'description']
    ordering_fields = ['name', 'price_min', 'featured', 'created_at']
    ordering = ['-featured', 'name']

    def get_serializer_class(self):
        if self.action == 'retrieve':
            return ServiceDetailSerializer
        return ServiceListSerializer

    def get_queryset(self):
        qs = (
            Service.objects.filter(
                is_active=True,
                organization__verification_status=(
                    Organization.VerificationStatus.VERIFIED
                ),
            )
            .select_related(
                'organization',
                'sub_category__category',
                'accepted_currency',
                'accepted_currency__currency',
                'country',
                'cities_city',
            )
        )
        if self.action == 'retrieve':
            return qs.prefetch_related(
                'media',
                'variants',
                Prefetch(
                    'feature_mappings',
                    queryset=ServiceFeatureMapping.objects.select_related(
                        'feature'
                    ),
                ),
            )
        return qs.prefetch_related('media')

    def filter_queryset(self, queryset):
        qs = super().filter_queryset(queryset)
        if 'country' not in self.request.query_params:
            country = getattr(self.request, 'country', None)
            if country is not None:
                qs = qs.filter(
                    Q(country_id=country.pk)
                    | Q(country__isnull=True, organization__country_id=country.pk)
                )
        return qs

    @action(detail=True, methods=['get'], url_path='open-slots')
    def open_slots(self, request, pk=None):
        """Return open appointment slots for a calendar day."""
        service = self.get_object()
        date_raw = request.query_params.get('date')
        if not date_raw:
            raise ValidationError({'date': [_('Query parameter date is required (YYYY-MM-DD).')]})
        day = parse_date(date_raw)
        if day is None:
            raise ValidationError({'date': [_('Invalid date. Use YYYY-MM-DD.')]})

        duration_raw = request.query_params.get('duration_minutes')
        if duration_raw is not None:
            try:
                duration_minutes = int(duration_raw)
            except (TypeError, ValueError):
                raise ValidationError(
                    {'duration_minutes': [_('duration_minutes must be an integer.')]}
                ) from None
        else:
            variant = service.variants.order_by('duration_minutes').first()
            duration_minutes = variant.duration_minutes if variant else 60

        exclude_booking = None
        exclude_raw = request.query_params.get('exclude_booking')
        if exclude_raw:
            exclude_booking = get_object_or_404(Booking, pk=exclude_raw, deleted_at__isnull=True)

        slots = AvailabilityService.list_open_slots(
            service=service,
            day=day,
            duration_minutes=duration_minutes,
            exclude_booking=exclude_booking,
        )
        return Response(
            {
                'date': day.isoformat(),
                'duration_minutes': duration_minutes,
                'slots': [
                    {
                        'start_time': s['start_time'].isoformat(),
                        'end_time': s['end_time'].isoformat(),
                    }
                    for s in slots
                ],
            },
            status=status.HTTP_200_OK,
        )
