from rest_framework import mixins, permissions, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.response import Response

from src.apps.organizations.models import (
    Organization,
    OrganizationMembership,
    OrganizationTypeModel,
)
from src.apps.organizations.serializers import (
    OrganizationCreateSerializer,
    OrganizationSerializer,
    OrganizationSubmitVerificationSerializer,
    OrganizationTeamMemberSerializer,
    OrganizationTypeSerializer,
    OrganizationUpdateSerializer,
)
from src.apps.users.models import User

_ORG_MODIFY_ROLES = frozenset({
    OrganizationMembership.OrganizationMemberRole.OWNER,
    OrganizationMembership.OrganizationMemberRole.ADMIN,
    OrganizationMembership.OrganizationMemberRole.MANAGER,
    OrganizationMembership.OrganizationMemberRole.STAFF,
})


class OrganizationTypeViewSet(viewsets.ReadOnlyModelViewSet):
    """List active organization types (for business registration)."""

    permission_classes = [permissions.IsAuthenticated]
    serializer_class = OrganizationTypeSerializer

    def get_queryset(self):
        return OrganizationTypeModel.objects.filter(is_active=True).order_by('display_name')


class OrganizationViewSet(
    mixins.ListModelMixin,
    mixins.RetrieveModelMixin,
    mixins.CreateModelMixin,
    mixins.UpdateModelMixin,
    viewsets.GenericViewSet,
):
    permission_classes = [permissions.IsAuthenticated]
    lookup_field = 'pk'

    def get_queryset(self):
        user = self.request.user
        if user.is_staff:
            return Organization.objects.all()
        return (
            Organization.objects.filter(memberships__user=user)
            .distinct()
            .order_by('name')
        )

    def get_serializer_class(self):
        if self.action == 'create':
            return OrganizationCreateSerializer
        if self.action in ('update', 'partial_update'):
            return OrganizationUpdateSerializer
        return OrganizationSerializer

    def perform_update(self, serializer):
        self._ensure_can_modify_organization(self.request.user, serializer.instance)
        serializer.save()

    def _ensure_can_modify_organization(self, user, org):
        if user.is_staff:
            return
        membership = OrganizationMembership.objects.filter(
            user=user, organization=org
        ).first()
        if not membership:
            raise PermissionDenied('You are not a member of this organization.')
        if membership.role not in _ORG_MODIFY_ROLES:
            raise PermissionDenied(
                'Insufficient permissions to update this organization.'
            )

    @action(
        detail=True,
        methods=['post'],
        parser_classes=[MultiPartParser, FormParser],
    )
    def submit_verification(self, request, pk=None):
        """Upload KYB documents; sets verification status to PENDING for staff review."""
        org = self.get_object()
        self._ensure_can_modify_organization(request.user, org)
        serializer = OrganizationSubmitVerificationSerializer(
            org,
            data=request.data,
            partial=True,
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        org.refresh_from_db()
        out = OrganizationSerializer(org, context={'request': request})
        return Response(out.data, status=200)

    @action(detail=True, methods=['get'])
    def team(self, request, pk=None):
        org = self.get_object()
        memberships = (
            OrganizationMembership.objects.filter(organization=org)
            .select_related('user')
            .order_by('user__email')
        )
        ser = OrganizationTeamMemberSerializer(memberships, many=True)
        return Response(ser.data)

    @action(detail=True, methods=['get'])
    def analytics(self, request, pk=None):
        org = self.get_object()
        return Response(
            {
                'organization_id': str(org.id),
                'total_bookings': 0,
                'revenue': '0.00',
                'currency': 'USD',
                'note': 'Aggregates require booking APIs (Phase 2).',
            }
        )
