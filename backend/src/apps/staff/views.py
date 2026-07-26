from datetime import timedelta
from decimal import Decimal

from django.db.models import Count, Q, Sum
from django.db.models.functions import TruncDate
from django.utils import timezone
from django.utils.dateparse import parse_date
from django.utils.translation import gettext as _
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from src.apps.bookings.models import Booking
from src.apps.finances.models import CategoryPlatformFee, PlatformFeeEntry, PlatformSettings
from src.apps.organizations.models import Organization, OrganizationSettings
from src.apps.payments.models import PaymentTransaction
from src.apps.services.models import ServiceCategory, ServiceFeature, ServiceSubCategory
from src.apps.services.pagination import CatalogPagination
from src.apps.staff.query import apply_ordering, apply_search
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


def _require_status(instance, allowed: set[str], *, field: str = 'verification_status'):
    current = getattr(instance, field)
    if current not in allowed:
        raise ValidationError(
            {
                field: _(
                    'This action is not allowed for the current verification status.'
                )
            }
        )


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
        qs = User.objects.filter(deleted_at__isnull=True)
        status_param = self.request.query_params.get('verification_status')
        if status_param:
            qs = qs.filter(verification_status=status_param)
        qs = apply_search(
            qs,
            self.request,
            ['email', 'first_name', 'last_name', 'username'],
        )
        return apply_ordering(
            qs,
            self.request,
            allowed={'updated_at', 'email', 'created_at'},
            default='-updated_at',
        )

    @action(detail=True, methods=['post'], url_path='approve')
    def approve(self, request, pk=None):
        user = self.get_object()
        _require_status(
            user,
            {
                User.VerificationStatus.PENDING,
                User.VerificationStatus.REJECTED,
            },
        )
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
        from src.apps.staff.notify import notify_kyc_approved

        notify_kyc_approved(user=user)
        return Response(
            StaffUserVerificationSerializer(user, context={'request': request}).data
        )

    @action(detail=True, methods=['post'], url_path='reject')
    def reject(self, request, pk=None):
        user = self.get_object()
        _require_status(user, {User.VerificationStatus.PENDING})
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
        from src.apps.staff.notify import notify_kyc_rejected

        notify_kyc_rejected(user=user, reason=reason)
        return Response(
            StaffUserVerificationSerializer(user, context={'request': request}).data
        )

    @action(detail=True, methods=['get'], url_path='wallet')
    def wallet(self, request, pk=None):
        from src.apps.payments.models import RefundWallet

        user = self.get_object()
        wallets = RefundWallet.objects.filter(user=user).select_related('currency')
        return Response(
            {
                'balances': [
                    {
                        'currency_code': w.currency.code,
                        'balance': str(w.balance),
                    }
                    for w in wallets
                ]
            }
        )

    @action(detail=True, methods=['post'], url_path='wallet/credit')
    def wallet_credit(self, request, pk=None):
        from decimal import Decimal

        from src.apps.finances.models import Currency
        from src.apps.payments.models import RefundWalletLedger
        from src.apps.payments.services.wallet import credit_wallet

        user = self.get_object()
        amount_raw = request.data.get('amount')
        currency_code = (request.data.get('currency_code') or '').strip().upper()
        note = (request.data.get('note') or '').strip()
        try:
            amount = Decimal(str(amount_raw))
        except Exception as exc:
            raise ValidationError({'amount': _('Invalid amount.')}) from exc
        if not currency_code:
            raise ValidationError({'currency_code': _('Currency is required.')})
        currency = Currency.objects.filter(code__iexact=currency_code).first()
        if not currency:
            raise ValidationError({'currency_code': _('Unknown currency.')})
        entry = credit_wallet(
            user=user,
            currency=currency,
            amount=amount,
            note=note or str(_('Manual staff credit')),
            kind=RefundWalletLedger.Kind.MANUAL,
            idempotency_key=(request.data.get('idempotency_key') or '')[:128],
        )
        return Response(
            {
                'id': str(entry.id),
                'balance_after': str(entry.balance_after),
                'currency_code': currency.code,
                'amount': str(entry.amount),
                'kind': entry.kind,
                'note': entry.note,
            },
            status=status.HTTP_200_OK,
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
        qs = Organization.objects.filter(deleted_at__isnull=True).select_related('type')
        status_param = self.request.query_params.get('verification_status')
        if status_param:
            qs = qs.filter(verification_status=status_param)
        qs = apply_search(qs, self.request, ['name', 'email'])
        return apply_ordering(
            qs,
            self.request,
            allowed={'updated_at', 'name', 'created_at'},
            default='-updated_at',
        )

    @action(detail=True, methods=['post'], url_path='approve')
    def approve(self, request, pk=None):
        org = self.get_object()
        _require_status(
            org,
            {
                Organization.VerificationStatus.PENDING,
                Organization.VerificationStatus.REJECTED,
            },
        )
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
        from src.apps.staff.notify import notify_kyb_approved

        notify_kyb_approved(organization=org)
        return Response(
            StaffOrganizationVerificationSerializer(
                org, context={'request': request}
            ).data
        )

    @action(detail=True, methods=['post'], url_path='reject')
    def reject(self, request, pk=None):
        org = self.get_object()
        _require_status(org, {Organization.VerificationStatus.PENDING})
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
        from src.apps.staff.notify import notify_kyb_rejected

        notify_kyb_rejected(organization=org, reason=reason)
        return Response(
            StaffOrganizationVerificationSerializer(
                org, context={'request': request}
            ).data
        )

    @action(detail=True, methods=['post'], url_path='suspend')
    def suspend(self, request, pk=None):
        org = self.get_object()
        _require_status(org, {Organization.VerificationStatus.VERIFIED})
        org.verification_status = Organization.VerificationStatus.SUSPENDED
        org.save(update_fields=['verification_status', 'updated_at'])
        return Response(
            StaffOrganizationVerificationSerializer(
                org, context={'request': request}
            ).data
        )

    @action(detail=True, methods=['post'], url_path='unsuspend')
    def unsuspend(self, request, pk=None):
        org = self.get_object()
        _require_status(org, {Organization.VerificationStatus.SUSPENDED})
        org.verification_status = Organization.VerificationStatus.VERIFIED
        org.verified_by = request.user
        org.verified_at = timezone.now()
        org.save(
            update_fields=[
                'verification_status',
                'verified_by',
                'verified_at',
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
        qs = ServiceCategory.objects.filter(deleted_at__isnull=True)
        qs = apply_search(qs, self.request, ['name', 'description'])
        return apply_ordering(
            qs,
            self.request,
            allowed={'sort_order', 'name', 'updated_at', 'created_at'},
            default='sort_order',
        )


class StaffServiceSubCategoryViewSet(viewsets.ModelViewSet):
    permission_classes = [IsStaffUser]
    serializer_class = StaffServiceSubCategorySerializer
    pagination_class = CatalogPagination
    http_method_names = ['get', 'post', 'patch', 'head', 'options']

    def get_queryset(self):
        qs = ServiceSubCategory.objects.filter(deleted_at__isnull=True).select_related(
            'category'
        )
        category = self.request.query_params.get('category')
        if category:
            qs = qs.filter(category_id=category)
        qs = apply_search(qs, self.request, ['name', 'description', 'category__name'])
        return apply_ordering(
            qs,
            self.request,
            allowed={'sort_order', 'name', 'updated_at', 'created_at'},
            default='sort_order',
        )


class StaffServiceFeatureViewSet(viewsets.ModelViewSet):
    permission_classes = [IsStaffUser]
    serializer_class = StaffServiceFeatureSerializer
    pagination_class = CatalogPagination
    http_method_names = ['get', 'post', 'patch', 'head', 'options']

    def get_queryset(self):
        qs = ServiceFeature.objects.filter(deleted_at__isnull=True)
        qs = apply_search(qs, self.request, ['name', 'description'])
        return apply_ordering(
            qs,
            self.request,
            allowed={'feature_type', 'name', 'updated_at', 'created_at'},
            default='feature_type',
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
        qs = PaymentTransaction.objects.select_related(
            'payment_provider',
            'currency',
            'user',
            'booking',
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
        qs = apply_search(
            qs,
            self.request,
            [
                'provider_reference',
                'client_reference',
                'user__email',
                'payment_provider__code',
            ],
        )
        return apply_ordering(
            qs,
            self.request,
            allowed={'created_at', 'amount', 'status', 'updated_at'},
            default='-created_at',
        )


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
        qs = CategoryPlatformFee.objects.filter(deleted_at__isnull=True).select_related(
            'category'
        )
        qs = apply_search(qs, self.request, ['category__name'])
        return apply_ordering(
            qs,
            self.request,
            allowed={'created_at', 'updated_at', 'rate'},
            default='category__sort_order',
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
        qs = PlatformFeeEntry.objects.select_related(
            'organization',
            'category',
            'currency',
            'booking',
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
        qs = apply_search(
            qs,
            self.request,
            ['organization__name', 'category__name', 'currency__code'],
        )
        return apply_ordering(
            qs,
            self.request,
            allowed={'created_at', 'amount', 'status'},
            default='-created_at',
        )

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


class StaffOverviewView(APIView):
    """Dashboard KPIs and short time-series for platform staff home."""

    permission_classes = [IsStaffUser]

    def get(self, request):
        today = timezone.localdate()
        start = today - timedelta(days=13)

        users = User.objects.filter(deleted_at__isnull=True)
        orgs = Organization.objects.filter(deleted_at__isnull=True)

        queues = {
            'pending_kyc': users.filter(
                verification_status=User.VerificationStatus.PENDING
            ).count(),
            'pending_kyb': orgs.filter(
                verification_status=Organization.VerificationStatus.PENDING
            ).count(),
            'suspended_orgs': orgs.filter(
                verification_status=Organization.VerificationStatus.SUSPENDED
            ).count(),
            'rejected_kyc': users.filter(
                verification_status=User.VerificationStatus.REJECTED
            ).count(),
            'rejected_kyb': orgs.filter(
                verification_status=Organization.VerificationStatus.REJECTED
            ).count(),
        }

        booking_rows = (
            Booking.objects.filter(
                deleted_at__isnull=True,
                created_at__date__gte=start,
                created_at__date__lte=today,
            )
            .annotate(day=TruncDate('created_at'))
            .values('day')
            .annotate(count=Count('id'))
            .order_by('day')
        )
        booking_by_day = {row['day']: row['count'] for row in booking_rows}

        payment_rows = (
            PaymentTransaction.objects.filter(
                created_at__date__gte=start,
                created_at__date__lte=today,
            )
            .annotate(day=TruncDate('created_at'))
            .values('day')
            .annotate(
                count=Count('id'),
                succeeded_amount=Sum(
                    'amount',
                    filter=Q(status=PaymentTransaction.TransactionStatus.SUCCEEDED),
                ),
            )
            .order_by('day')
        )
        payment_by_day = {
            row['day']: {
                'count': row['count'],
                'succeeded_amount': row['succeeded_amount'] or Decimal('0'),
            }
            for row in payment_rows
        }

        bookings_last_14_days = []
        payments_last_14_days = []
        for offset in range(14):
            day = start + timedelta(days=offset)
            bookings_last_14_days.append(
                {
                    'date': day.isoformat(),
                    'count': booking_by_day.get(day, 0),
                }
            )
            pay = payment_by_day.get(day, {'count': 0, 'succeeded_amount': Decimal('0')})
            payments_last_14_days.append(
                {
                    'date': day.isoformat(),
                    'count': pay['count'],
                    'succeeded_amount': f'{pay["succeeded_amount"]:.2f}',
                }
            )

        fee_rows = (
            PlatformFeeEntry.objects.values('currency__code')
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
        fees_by_currency = []
        for row in fee_rows:
            accrued = row['total_accrued'] or Decimal('0')
            reversed_amt = row['total_reversed'] or Decimal('0')
            fees_by_currency.append(
                {
                    'currency': row['currency__code'],
                    'total_accrued': f'{accrued:.2f}',
                    'total_reversed': f'{reversed_amt:.2f}',
                    'net_fees': f'{max(Decimal("0"), accrued - reversed_amt):.2f}',
                }
            )

        return Response(
            {
                'queues': queues,
                'bookings_last_14_days': bookings_last_14_days,
                'payments_last_14_days': payments_last_14_days,
                'fees_by_currency': fees_by_currency,
            }
        )
