from django.db.models import Prefetch
from django.shortcuts import get_object_or_404
from django.utils.translation import gettext as _
from rest_framework import permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.response import Response

from src.apps.organizations.models import Organization, OrganizationMembership
from src.apps.services.models import Service, ServiceFeatureMapping, ServiceMedia
from src.apps.services.pagination import CatalogPagination
from src.apps.services.serializers import (
    ServiceDetailSerializer,
    ServiceListSerializer,
    ServiceWriteSerializer,
)

_ORG_MODIFY_ROLES = frozenset({
    OrganizationMembership.OrganizationMemberRole.OWNER,
    OrganizationMembership.OrganizationMemberRole.ADMIN,
    OrganizationMembership.OrganizationMemberRole.MANAGER,
    OrganizationMembership.OrganizationMemberRole.STAFF,
})


class OrganizationServiceViewSet(viewsets.ModelViewSet):
    """CRUD services for a single organization (verified orgs for non-staff)."""

    permission_classes = [permissions.IsAuthenticated]
    pagination_class = CatalogPagination
    lookup_field = 'pk'
    ordering_fields = ['name', 'price_min', 'featured', 'created_at']
    ordering = ['-featured', 'name']

    def initial(self, request, *args, **kwargs):
        super().initial(request, *args, **kwargs)
        self._organization = get_object_or_404(
            Organization,
            pk=self.kwargs['organization_pk'],
        )
        self._ensure_can_modify_and_verified(request.user, self._organization)

    def get_queryset(self):
        org_id = self.kwargs['organization_pk']
        qs = (
            Service.objects.filter(organization_id=org_id)
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
        return qs.prefetch_related('media', 'variants')

    def get_serializer_class(self):
        if self.action in ('create', 'update', 'partial_update'):
            return ServiceWriteSerializer
        if self.action == 'retrieve':
            return ServiceDetailSerializer
        return ServiceListSerializer

    def get_serializer_context(self):
        ctx = super().get_serializer_context()
        ctx['organization'] = getattr(self, '_organization', None)
        return ctx

    def perform_create(self, serializer):
        serializer.save(organization=self._organization)

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        out = ServiceDetailSerializer(
            serializer.instance,
            context={'request': request},
        )
        return Response(out.data, status=status.HTTP_201_CREATED)

    def update(self, request, *args, **kwargs):
        partial = kwargs.pop('partial', False)
        instance = self.get_object()
        serializer = self.get_serializer(
            instance,
            data=request.data,
            partial=partial,
        )
        serializer.is_valid(raise_exception=True)
        self.perform_update(serializer)
        out = ServiceDetailSerializer(
            serializer.instance,
            context={'request': request},
        )
        return Response(out.data)

    @action(
        detail=True,
        methods=['post'],
        parser_classes=[MultiPartParser, FormParser],
        url_path='media',
    )
    def upload_media(self, request, pk=None, organization_pk=None):
        """Multipart upload of a primary service image. Field name: `file`."""
        if 'file' not in request.FILES:
            return Response(
                {'error': _('Image file is required')},
                status=status.HTTP_400_BAD_REQUEST,
            )
        service = self.get_object()
        uploaded = request.FILES['file']
        ServiceMedia.objects.filter(
            service=service,
            is_primary=True,
        ).update(is_primary=False)
        ServiceMedia.objects.create(
            service=service,
            media_type=ServiceMedia.ServiceMediaType.IMAGE,
            file=uploaded,
            title=getattr(uploaded, 'name', '')[:255],
            is_primary=True,
            sort_order=0,
        )
        out = ServiceDetailSerializer(service, context={'request': request})
        return Response(out.data, status=status.HTTP_200_OK)

    def _ensure_can_modify_and_verified(self, user, org):
        if user.is_staff:
            return
        membership = OrganizationMembership.objects.filter(
            user=user, organization=org
        ).first()
        if not membership:
            raise PermissionDenied('You are not a member of this organization.')
        if membership.role not in _ORG_MODIFY_ROLES:
            raise PermissionDenied(
                'Insufficient permissions to manage services for this organization.'
            )
        if org.verification_status != Organization.VerificationStatus.VERIFIED:
            raise PermissionDenied(
                'Organization must be verified to manage services.'
            )
