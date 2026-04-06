from django.db.models import Prefetch
from rest_framework import permissions, viewsets

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


class ServiceSubCategoryViewSet(viewsets.ReadOnlyModelViewSet):
    """List active subcategories (for provider service forms)."""

    permission_classes = [permissions.IsAuthenticated]
    serializer_class = ServiceSubCategoryBriefSerializer
    pagination_class = None

    def get_queryset(self):
        return ServiceSubCategory.objects.filter(is_active=True).select_related(
            'category'
        ).order_by('category__sort_order', 'sort_order', 'name')


class ServiceFeatureViewSet(viewsets.ReadOnlyModelViewSet):
    """List global service features (for provider mappings)."""

    permission_classes = [permissions.IsAuthenticated]
    serializer_class = ServiceFeatureNestedSerializer
    pagination_class = None

    def get_queryset(self):
        return ServiceFeature.objects.all().order_by('feature_type', 'name')


class ServiceCategoryViewSet(viewsets.ReadOnlyModelViewSet):
    """List active service categories (icons from `ServiceCategory.icon`)."""

    permission_classes = [permissions.IsAuthenticated]
    serializer_class = ServiceCategorySerializer

    def get_queryset(self):
        return ServiceCategory.objects.filter(is_active=True).order_by(
            'sort_order', 'name'
        )


class ServiceCatalogViewSet(viewsets.ReadOnlyModelViewSet):
    """List active services for the client catalog (search + filters)."""

    permission_classes = [permissions.IsAuthenticated]
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
