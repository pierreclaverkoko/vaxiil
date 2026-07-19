from decimal import Decimal

from django.db.models import Q, Sum
from django.utils import timezone
from django.utils.dateparse import parse_date
from django.utils.translation import gettext as _
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from src.apps.finances.models import CategoryPlatformFee, PlatformFeeEntry, PlatformSettings
from src.apps.organizations.models import Organization, OrganizationSettings
from src.apps.payments.models import PaymentTransaction
from src.apps.services.models import ServiceCategory, ServiceFeature, ServiceSubCategory
from src.apps.services.pagination import CatalogPagination
from src.apps.staff.serializers import (
    StaffCategoryPlatformFeeSerializer,
    StaffOrganizationFeeSettingsSerializer,
    StaffOrganizationVerificationSerializer,
    StaffPaymentTransactionSerializer,
    StaffPlatformFeeEntrySerializer,
    StaffPlatformSettingsSerializer,
    StaffRejectSerializer,
    StaffServiceCategorySerializer,
    StaffServiceFeatureSerializer,
    StaffServiceSubCategorySerializer,
    StaffUserVerificationSerializer,
    require_rejection_reason,
)
from src.apps.users.models import User
from src.apps.users.permissions import IsStaffUser


class StaffUserVerificationViewSet(
    mixins.ListModelMixin,
    mixins.RetrieveModelMixin,
    viewsets.GenericViewSet,
):
    """KYC review queue for platform staff."""

    permission_classes = [IsStaffUser]
    serializer_class = StaffUserVerificationSerializer
    pagination_class = CatalogPagination

    def get_queryset(self):
        qs = User.objects.filter(deleted_at__isnull=True).order_by('-updated_at')
        status_param = self.request.query_params.get('verification_status')
        if status_param:
            qs = qs.filter(verification_status=status_param)
        return qs

    @action(detail=True, methods=['post'], url_path='approve')
    def approve(self, request, pk=None):
        user = self.get_object()
        user.verification_status = User.VerificationStatus.VERIFIED
        user.is_trusted = True
        user.verified_by = request.user
        user.verified_at = timezone.now()
        user.rejection_reason = ''
        user.save(
            update_fields=[
                'verification_status',
                'is_trusted',
                'verified_by',
                'verified_at',
                'rejection_reason',
                'updated_at',
            ]
        )
        return Response(
            StaffUserVerificationSerializer(user, context={'request': request}).data
        )

    @action(detail=True, methods=['post'], url_path='reject')
    def reject(self, request, pk=None):
        user = self.get_object()
        ser = StaffRejectSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        reason = require_rejection_reason(ser.validated_data.get('reason', ''))
        user.verification_status = User.VerificationStatus.REJECTED
        user.is_trusted = False
        user.rejection_reason = reason
        user.save(
            update_fields=[
                'verification_status',
                'is_trusted',
                'rejection_reason',
                'updated_at',
            ]
        )
        return Response(
            StaffUserVerificationSerializer(user, context={'request': request}).data
        )


class StaffOrganizationVerificationViewSet(
    mixins.ListModelMixin,
    mixins.RetrieveModelMixin,
    viewsets.GenericViewSet,
):
    """KYB review queue for platform staff."""

    permission_classes = [IsStaffUser]
    serializer_class = StaffOrganizationVerificationSerializer
    pagination_class = CatalogPagination

    def get_queryset(self):
        qs = (
            Organization.objects.filter(deleted_at__isnull=True)
            .select_related('type')
            .order_by('-updated_at')
        )
        status_param = self.request.query_params.get('verification_status')
        if status_param:
            qs = qs.filter(verification_status=status_param)
        return qs

    @action(detail=True, methods=['post'], url_path='approve')
    def approve(self, request, pk=None):
        org = self.get_object()
        org.verification_status = Organization.VerificationStatus.VERIFIED
        org.verified_by = request.user
        org.verified_at = timezone.now()
        org.rejection_reason = ''
        org.save(
            update_fields=[
                'verification_status',
                'verified_by',
                'verified_at',
                'rejection_reason',
                'updated_at',
            ]
        )
        return Response(
            StaffOrganizationVerificationSerializer(
                org, context={'request': request}
            ).data
        )

    @action(detail=True, methods=['post'], url_path='reject')
    def reject(self, request, pk=None):
        org = self.get_object()
        ser = StaffRejectSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        reason = require_rejection_reason(ser.validated_data.get('reason', ''))
        org.verification_status = Organization.VerificationStatus.REJECTED
        org.rejection_reason = reason
        org.save(
            update_fields=[
                'verification_status',
                'rejection_reason',
                'updated_at',
            ]
        )
        return Response(
            StaffOrganizationVerificationSerializer(
                org, context={'request': request}
            ).data
        )


class StaffServiceCategoryViewSet(viewsets.ModelViewSet):
    permission_classes = [IsStaffUser]
    serializer_class = StaffServiceCategorySerializer
    pagination_class = CatalogPagination
    http_method_names = ['get', 'post', 'patch', 'head', 'options']

    def get_queryset(self):
        return ServiceCategory.objects.filter(deleted_at__isnull=True).order_by(
            'sort_order', 'name'
        )


class StaffServiceSubCategoryViewSet(viewsets.ModelViewSet):
    permission_classes = [IsStaffUser]
    serializer_class = StaffServiceSubCategorySerializer
    pagination_class = CatalogPagination
    http_method_names = ['get', 'post', 'patch', 'head', 'options']

    def get_queryset(self):
        return (
            ServiceSubCategory.objects.filter(deleted_at__isnull=True)
            .select_related('category')
            .order_by('category__sort_order', 'sort_order', 'name')
        )


class StaffServiceFeatureViewSet(viewsets.ModelViewSet):
    permission_classes = [IsStaffUser]
    serializer_class = StaffServiceFeatureSerializer
    pagination_class = CatalogPagination
    http_method_names = ['get', 'post', 'patch', 'head', 'options']

    def get_queryset(self):
        return ServiceFeature.objects.filter(deleted_at__isnull=True).order_by(
            'feature_type', 'name'
        )


class StaffPaymentTransactionViewSet(
    mixins.ListModelMixin,
    mixins.RetrieveModelMixin,
    viewsets.GenericViewSet,
):
    """Read-only payments ledger for platform staff."""

    permission_classes = [IsStaffUser]
    serializer_class = StaffPaymentTransactionSerializer
    pagination_class = CatalogPagination

    def get_queryset(self):
        qs = (
            PaymentTransaction.objects.select_related(
                'payment_provider',
                'currency',
                'user',
                'booking',
            )
            .order_by('-created_at')
        )
        status_param = self.request.query_params.get('status')
        if status_param:
            qs = qs.filter(status=status_param)
        provider = self.request.query_params.get('provider')
        if provider:
            qs = qs.filter(payment_provider__code=provider)
        booking_id = self.request.query_params.get('booking')
        if booking_id:
            qs = qs.filter(booking_id=booking_id)
        return qs


class StaffPlatformSettingsView(APIView):
    """Global platform fee rate (singleton)."""

    permission_classes = [IsStaffUser]

    def get(self, request):
        solo = PlatformSettings.get_solo()
        return Response(StaffPlatformSettingsSerializer(solo).data)

    def patch(self, request):
        solo = PlatformSettings.get_solo()
        ser = StaffPlatformSettingsSerializer(solo, data=request.data, partial=True)
        ser.is_valid(raise_exception=True)
        ser.save()
        return Response(ser.data)


class StaffCategoryPlatformFeeViewSet(viewsets.ModelViewSet):
    permission_classes = [IsStaffUser]
    serializer_class = StaffCategoryPlatformFeeSerializer
    pagination_class = CatalogPagination
    http_method_names = ['get', 'post', 'patch', 'delete', 'head', 'options']

    def get_queryset(self):
        return (
            CategoryPlatformFee.objects.filter(deleted_at__isnull=True)
            .select_related('category')
            .order_by('category__sort_order', 'category__name')
        )

    def perform_destroy(self, instance):
        instance.delete()


class StaffPlatformFeeEntryViewSet(
    mixins.ListModelMixin,
    mixins.RetrieveModelMixin,
    viewsets.GenericViewSet,
):
    """Platform fee ledger + period summary."""

    permission_classes = [IsStaffUser]
    serializer_class = StaffPlatformFeeEntrySerializer
    pagination_class = CatalogPagination

    def get_queryset(self):
        qs = (
            PlatformFeeEntry.objects.select_related(
                'organization',
                'category',
                'currency',
                'booking',
            )
            .order_by('-created_at')
        )
        org = self.request.query_params.get('organization')
        if org:
            qs = qs.filter(organization_id=org)
        category = self.request.query_params.get('category')
        if category:
            qs = qs.filter(category_id=category)
        payer = self.request.query_params.get('payer')
        if payer:
            qs = qs.filter(payer=payer)
        status_param = self.request.query_params.get('status')
        if status_param:
            qs = qs.filter(status=status_param)
        date_from = self.request.query_params.get('date_from')
        if date_from:
            parsed = parse_date(date_from)
            if parsed is None:
                raise ValidationError({'date_from': _('Use a date in YYYY-MM-DD format.')})
            qs = qs.filter(created_at__date__gte=parsed)
        date_to = self.request.query_params.get('date_to')
        if date_to:
            parsed = parse_date(date_to)
            if parsed is None:
                raise ValidationError({'date_to': _('Use a date in YYYY-MM-DD format.')})
            qs = qs.filter(created_at__date__lte=parsed)
        return qs

    @action(detail=False, methods=['get'], url_path='summary')
    def summary(self, request):
        qs = self.get_queryset()
        rows = (
            qs.values('currency__code')
            .annotate(
                total_accrued=Sum(
                    'amount',
                    filter=Q(status=PlatformFeeEntry.EntryStatus.ACCRUED),
                ),
                total_reversed=Sum(
                    'amount',
                    filter=Q(status=PlatformFeeEntry.EntryStatus.REVERSED),
                ),
            )
            .order_by('currency__code')
        )
        by_currency = []
        for row in rows:
            accrued = row['total_accrued'] or Decimal('0')
            reversed_amt = row['total_reversed'] or Decimal('0')
            by_currency.append(
                {
                    'currency': row['currency__code'],
                    'total_accrued': f'{accrued:.2f}',
                    'total_reversed': f'{reversed_amt:.2f}',
                    'net_fees': f'{max(Decimal("0"), accrued - reversed_amt):.2f}',
                }
            )
        return Response({'by_currency': by_currency})


class StaffOrganizationFeeSettingsView(APIView):
    """Staff-managed org fee override + payer. Contact the company when setting a company rate."""

    permission_classes = [IsStaffUser]

    def get(self, request, pk=None):
        org = Organization.objects.filter(pk=pk, deleted_at__isnull=True).first()
        if org is None:
            return Response(status=status.HTTP_404_NOT_FOUND)
        settings_row, _ = OrganizationSettings.objects.get_or_create(organization=org)
        return Response(StaffOrganizationFeeSettingsSerializer(settings_row).data)

    def patch(self, request, pk=None):
        org = Organization.objects.filter(pk=pk, deleted_at__isnull=True).first()
        if org is None:
            return Response(status=status.HTTP_404_NOT_FOUND)
        settings_row, _ = OrganizationSettings.objects.get_or_create(organization=org)
        ser = StaffOrganizationFeeSettingsSerializer(
            settings_row,
            data=request.data,
            partial=True,
        )
        ser.is_valid(raise_exception=True)
        ser.save()
        return Response(ser.data)
