from django.db.models import Prefetch
from rest_framework import mixins, permissions, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.response import Response

from src.apps.bookings.models import Booking
from src.apps.organizations.models import (
    Country,
    CountryAcceptedCurrency,
    Organization,
    OrganizationMembership,
    OrganizationTypeModel,
)
from src.apps.organizations.serializers import (
    OrganizationCreateSerializer,
    OrganizationDiscoverySerializer,
    OrganizationSerializer,
    OrganizationSubmitVerificationSerializer,
    OrganizationTeamMemberSerializer,
    OrganizationTypeSerializer,
    OrganizationUpdateSerializer,
)
from src.apps.organizations.serializers_geo import (
    CountryAcceptedCurrencySerializer,
    CountryBriefSerializer,
)

_ORG_MODIFY_ROLES = frozenset({
    OrganizationMembership.OrganizationMemberRole.OWNER,
    OrganizationMembership.OrganizationMemberRole.ADMIN,
    OrganizationMembership.OrganizationMemberRole.MANAGER,
    OrganizationMembership.OrganizationMemberRole.STAFF,
})


class CountryViewSet(viewsets.ReadOnlyModelViewSet):
    """List countries (registration / address FK)."""

    permission_classes = [permissions.AllowAny]
    serializer_class = CountryBriefSerializer

    def get_queryset(self):
        return Country.objects.filter(
            is_active=True,
            deleted_at__isnull=True,
        ).order_by('name')


class CountryAcceptedCurrencyViewSet(viewsets.ReadOnlyModelViewSet):
    """Accepted currencies per country (filter with ?country=<uuid>)."""

    permission_classes = [permissions.AllowAny]
    serializer_class = CountryAcceptedCurrencySerializer

    def get_queryset(self):
        qs = CountryAcceptedCurrency.objects.filter(
            is_active=True,
            deleted_at__isnull=True,
        ).select_related('country', 'currency')
        country_id = self.request.query_params.get('country')
        if country_id:
            qs = qs.filter(country_id=country_id)
        return qs.order_by('country__name', 'currency__code')


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

    def get_parser_classes(self):
        if self.action in ('create', 'update', 'partial_update'):
            return [JSONParser, MultiPartParser, FormParser]
        return super().get_parser_classes()

    def get_queryset(self):
        user = self.request.user
        if user.is_staff:
            qs = Organization.objects.all()
        else:
            qs = (
                Organization.objects.filter(memberships__user=user)
                .distinct()
            )
        return qs.select_related(
            'country',
            'default_currency',
            'default_currency__currency',
            'type',
        ).prefetch_related(
            'addresses',
            'addresses__country',
            Prefetch(
                'memberships',
                queryset=OrganizationMembership.objects.filter(
                    user=user,
                ).only('id', 'organization_id', 'role'),
            ),
        ).order_by('name')

    def get_serializer_class(self):
        if self.action == 'create':
            return OrganizationCreateSerializer
        if self.action in ('update', 'partial_update'):
            return OrganizationUpdateSerializer
        return OrganizationSerializer

    @action(detail=False, methods=['get'], url_path='discovery')
    def discovery(self, request):
        """List verified organizations accepting bookings (client discovery, not membership-scoped)."""
        qs = (
            Organization.objects.filter(
                verification_status=Organization.VerificationStatus.VERIFIED,
                is_active=True,
                accepts_bookings=True,
            )
            .select_related('type', 'country')
            .prefetch_related('addresses', 'addresses__country')
            .order_by('name')[:20]
        )
        ser = OrganizationDiscoverySerializer(
            qs, many=True, context={'request': request}
        )
        return Response(ser.data)

    @action(detail=False, methods=['get'], url_path='mine-summary')
    def mine_summary(self, request):
        """Aggregate stats across organizations the current user can list (memberships)."""
        qs = self.get_queryset()
        org_ids = list(qs.values_list('pk', flat=True))
        collective_beneficiaries = (
            Booking.objects.filter(
                organization_id__in=org_ids,
                deleted_at__isnull=True,
                status=Booking.BookingStatus.COMPLETED,
            ).count()
        )
        return Response(
            {
                'organization_count': len(org_ids),
                'collective_beneficiaries': collective_beneficiaries,
            }
        )

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
        url_path='submit-verification',
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
        code = 'USD'
        if org.default_currency_id and org.default_currency.currency_id:
            code = org.default_currency.currency.code
        return Response(
            {
                'organization_id': str(org.id),
                'total_bookings': 0,
                'revenue': '0.00',
                'currency': code,
                'note': 'Revenue aggregates are placeholders until reporting is wired.',
            }
        )
