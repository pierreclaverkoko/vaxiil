from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils.translation import gettext as _
from rest_framework import permissions, status, viewsets
from rest_framework.exceptions import PermissionDenied
from rest_framework.response import Response

from src.apps.organizations.models import (
    Organization,
    OrganizationAddress,
    OrganizationMembership,
)
from src.apps.organizations.serializers import (
    OrganizationAddressSerializer,
    OrganizationAddressWriteSerializer,
)
from src.apps.users.permissions import IsEmailVerified

_ORG_MODIFY_ROLES = frozenset(
    {
        OrganizationMembership.OrganizationMemberRole.OWNER,
        OrganizationMembership.OrganizationMemberRole.ADMIN,
        OrganizationMembership.OrganizationMemberRole.MANAGER,
        OrganizationMembership.OrganizationMemberRole.STAFF,
    }
)


class OrganizationAddressViewSet(viewsets.ModelViewSet):
    """CRUD operating addresses for a single organization."""

    permission_classes = [permissions.IsAuthenticated, IsEmailVerified]
    lookup_field = 'pk'
    http_method_names = ['get', 'post', 'put', 'patch', 'delete', 'head', 'options']

    def initial(self, request, *args, **kwargs):
        super().initial(request, *args, **kwargs)
        self._organization = get_object_or_404(
            Organization,
            pk=self.kwargs['organization_pk'],
        )
        self._ensure_can_modify(request.user, self._organization)

    def get_queryset(self):
        return (
            OrganizationAddress.objects.filter(
                organization_id=self.kwargs['organization_pk'],
                deleted_at__isnull=True,
            )
            .select_related('country', 'cities_city', 'cities_city__country')
            .order_by('-is_primary', 'created_at')
        )

    def get_serializer_class(self):
        if self.action in ('create', 'update', 'partial_update'):
            return OrganizationAddressWriteSerializer
        return OrganizationAddressSerializer

    def perform_create(self, serializer):
        org = self._organization
        with transaction.atomic():
            is_primary = bool(serializer.validated_data.get('is_primary'))
            if is_primary or not org.addresses.filter(deleted_at__isnull=True).exists():
                org.addresses.filter(deleted_at__isnull=True, is_primary=True).update(
                    is_primary=False
                )
                serializer.save(
                    organization=org,
                    is_primary=True,
                    country=serializer.validated_data.get('country') or org.country,
                )
            else:
                serializer.save(
                    organization=org,
                    country=serializer.validated_data.get('country') or org.country,
                )

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        read = OrganizationAddressSerializer(
            serializer.instance,
            context=self.get_serializer_context(),
        )
        headers = self.get_success_headers(read.data)
        return Response(read.data, status=status.HTTP_201_CREATED, headers=headers)

    def update(self, request, *args, **kwargs):
        partial = kwargs.pop('partial', False)
        instance = self.get_object()
        serializer = self.get_serializer(instance, data=request.data, partial=partial)
        serializer.is_valid(raise_exception=True)
        self.perform_update(serializer)
        read = OrganizationAddressSerializer(
            serializer.instance,
            context=self.get_serializer_context(),
        )
        return Response(read.data)

    def perform_update(self, serializer):
        with transaction.atomic():
            instance = serializer.instance
            making_primary = serializer.validated_data.get('is_primary', instance.is_primary)
            if making_primary:
                OrganizationAddress.objects.filter(
                    organization=instance.organization,
                    deleted_at__isnull=True,
                    is_primary=True,
                ).exclude(pk=instance.pk).update(is_primary=False)
            serializer.save()

    def destroy(self, request, *args, **kwargs):
        from src.apps.bookings.location_types import (
            has_usable_venue_address,
            strip_office_from_org_location_types,
        )

        instance = self.get_object()
        org = instance.organization
        if instance.is_primary:
            siblings = (
                OrganizationAddress.objects.filter(
                    organization=org,
                    deleted_at__isnull=True,
                )
                .exclude(pk=instance.pk)
                .order_by('created_at')
            )
            next_primary = siblings.first()
            instance.delete()
            if next_primary is not None:
                next_primary.is_primary = True
                next_primary.save(update_fields=['is_primary', 'updated_at'])
        else:
            instance.delete()
        if not has_usable_venue_address(org):
            strip_office_from_org_location_types(org)
        return Response(status=status.HTTP_204_NO_CONTENT)

    @staticmethod
    def _ensure_can_modify(user, org):
        membership = OrganizationMembership.objects.filter(
            user=user, organization=org
        ).first()
        if not membership or membership.role not in _ORG_MODIFY_ROLES:
            raise PermissionDenied(
                _('You do not have permission to manage this organization.')
            )
