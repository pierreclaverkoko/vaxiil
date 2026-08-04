from __future__ import annotations

import json
from decimal import Decimal, InvalidOperation

from django.conf import settings
from django.http import HttpResponseRedirect
from django.shortcuts import get_object_or_404
from django.utils.decorators import method_decorator
from django.views.decorators.csrf import csrf_exempt
from rest_framework import permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView

from src.apps.bookings.models import Booking
from src.apps.payments.models import PaymentTransaction
from src.apps.payments.serializers import (
    ConsumerPaymentTransactionSerializer,
    serialize_consumer_transaction_detail,
)
from src.apps.payments.transaction_display import (
    prefetch_payment_methods_for_transactions,
)
from src.apps.payments.services.payment_links import (
    collect_for_booking,
    fund_wallet,
)
from src.apps.payments.services.status_sync import refresh_deposit_status
from src.apps.payments.services.wallet import wallet_summary_for
from src.apps.payments.services.webhooks import (
    handle_mainmoney_webhook,
    handle_mm_aggregator_webhook,
    handle_redirect_callback,
)
from src.apps.services.pagination import CatalogPagination
from src.apps.staff.query import apply_ordering
from django.utils.translation import gettext as _
from src.apps.users.permissions import IsEmailVerified, IsVerifiedUser


def _parse_details(raw) -> dict | None:
    if raw is None or raw == '':
        return None
    if isinstance(raw, dict):
        return {str(k): str(v) for k, v in raw.items()}
    return None


class PaymentLinkViewSet(viewsets.ViewSet):
    """Authenticated collection for bookings and wallet funding."""

    permission_classes = [permissions.IsAuthenticated, IsEmailVerified]

    def get_permissions(self):
        if getattr(self, 'action', None) == 'wallet_top_up':
            return [
                permissions.IsAuthenticated(),
                IsEmailVerified(),
                IsVerifiedUser(),
            ]
        return super().get_permissions()

    @action(detail=False, methods=['get'], url_path='wallet')
    def wallet(self, request):
        return Response(wallet_summary_for(request.user), status=status.HTTP_200_OK)

    @action(detail=False, methods=['post'], url_path='wallet/top-up')
    def wallet_top_up(self, request):
        if not request.user.is_verified:
            return Response(
                {
                    'detail': _(
                        'Verify your identity before adding funds. Complete KYC from your profile.'
                    )
                },
                status=status.HTTP_403_FORBIDDEN,
            )
        raw_amount = request.data.get('amount')
        currency_code = (request.data.get('currency_code') or '').strip()
        if raw_amount is None or raw_amount == '':
            return Response(
                {'amount': ['This field is required.']},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            amount = Decimal(str(raw_amount))
        except (InvalidOperation, TypeError, ValueError):
            return Response(
                {'amount': ['Invalid amount.']},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not currency_code:
            return Response(
                {'currency_code': ['This field is required.']},
                status=status.HTTP_400_BAD_REQUEST,
            )
        callback_url = request.build_absolute_uri(
            '/api/v1/payments/webhooks/mm_aggregator/'
        )
        result = fund_wallet(
            user=request.user,
            amount=amount,
            currency_code=currency_code,
            payment_method_id=str(request.data.get('payment_method_id') or '')
            or None,
            account_identifier=str(request.data.get('account_identifier') or ''),
            account_name=str(request.data.get('account_name') or '') or None,
            details=_parse_details(request.data.get('details')),
            callback_url=callback_url,
            request=request,
        )
        return Response(
            {
                'merchant_reference': result.merchant_reference,
                'transaction_id': result.transaction_id,
                'amount': str(result.amount),
                'status': result.status,
                'message': result.message,
            },
            status=status.HTTP_201_CREATED,
        )

    @action(
        detail=False,
        methods=['post'],
        url_path=r'bookings/(?P<booking_id>[^/.]+)/payment-link',
    )
    def create_for_booking(self, request, booking_id=None):
        booking = get_object_or_404(
            Booking.objects.select_related(
                'accepted_currency__currency',
                'service__accepted_currency__currency',
            ),
            pk=booking_id,
            deleted_at__isnull=True,
        )
        callback_url = request.build_absolute_uri(
            '/api/v1/payments/webhooks/mm_aggregator/'
        )
        apply_wallet = bool(request.data.get('apply_wallet', False))
        wallet_amount = None
        raw_amount = request.data.get('wallet_amount')
        if raw_amount is not None and raw_amount != '':
            try:
                wallet_amount = Decimal(str(raw_amount))
            except (InvalidOperation, TypeError, ValueError):
                return Response(
                    {'wallet_amount': ['Invalid amount.']},
                    status=status.HTTP_400_BAD_REQUEST,
                )
        result = collect_for_booking(
            booking=booking,
            user=request.user,
            payment_method_id=str(request.data.get('payment_method_id') or '')
            or None,
            account_identifier=str(request.data.get('account_identifier') or ''),
            account_name=str(request.data.get('account_name') or '') or None,
            details=_parse_details(request.data.get('details')),
            apply_wallet=apply_wallet,
            wallet_amount=wallet_amount,
            callback_url=callback_url,
            request=request,
        )
        return Response(
            {
                'merchant_reference': result.merchant_reference,
                'transaction_id': result.transaction_id,
                'amount_charged': str(result.amount_charged),
                'wallet_applied': str(result.wallet_applied),
                'fully_paid': result.fully_paid,
                'status': result.status,
                'message': result.message,
            },
            status=status.HTTP_201_CREATED,
        )

    @action(detail=False, methods=['get'], url_path='transactions')
    def transaction_list(self, request):
        """Paginated payment history for the authenticated payer."""
        qs = PaymentTransaction.objects.filter(user=request.user).select_related(
            'payment_provider',
            'currency',
            'booking',
        )
        status_param = (request.query_params.get('status') or '').strip()
        if status_param:
            qs = qs.filter(status=status_param)
        purpose_param = (request.query_params.get('purpose') or '').strip()
        if purpose_param:
            qs = qs.filter(purpose=purpose_param)
        qs = apply_ordering(
            qs,
            request,
            allowed={'created_at', 'amount', 'status', 'updated_at'},
            default='-created_at',
        )
        paginator = CatalogPagination()
        page = paginator.paginate_queryset(qs, request, view=self)
        rows = list(page if page is not None else qs)
        methods_by_id = prefetch_payment_methods_for_transactions(rows)
        ser = ConsumerPaymentTransactionSerializer(
            rows,
            many=True,
            context={
                'request': request,
                '_payment_methods_by_id': methods_by_id,
            },
        )
        if page is not None:
            return paginator.get_paginated_response(ser.data)
        return Response(ser.data)

    def _owned_transaction(self, request, client_reference: str):
        return (
            PaymentTransaction.objects.filter(
                client_reference=client_reference,
                user=request.user,
            )
            .select_related('payment_provider', 'currency', 'booking')
            .order_by('-created_at')
            .first()
        )

    @action(
        detail=False,
        methods=['get'],
        url_path=r'transactions/(?P<client_reference>[^/.]+)',
    )
    def transaction_status(self, request, client_reference=None):
        txn = self._owned_transaction(request, client_reference or '')
        if txn is None:
            return Response({'detail': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)
        return Response(
            serialize_consumer_transaction_detail(txn, request=request)
        )

    @action(
        detail=False,
        methods=['post'],
        url_path=r'transactions/(?P<client_reference>[^/.]+)/refresh',
    )
    def transaction_refresh(self, request, client_reference=None):
        txn = self._owned_transaction(request, client_reference or '')
        if txn is None:
            return Response({'detail': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)
        try:
            txn = refresh_deposit_status(txn)
        except RuntimeError as exc:
            return Response(
                {'detail': str(exc)},
                status=status.HTTP_502_BAD_GATEWAY,
            )
        return Response(
            serialize_consumer_transaction_detail(txn, request=request)
        )


@method_decorator(csrf_exempt, name='dispatch')
class MainmoneyWebhookView(APIView):
    authentication_classes = []
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        raw = request.body
        try:
            payload = json.loads(raw.decode('utf-8') or '{}')
        except json.JSONDecodeError:
            return Response(
                {'detail': 'invalid_json'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        signature = request.headers.get('X-Mainmoney-Signature', '')
        event = request.headers.get('X-Mainmoney-Event', '')
        ok, message = handle_mainmoney_webhook(
            raw_body=raw,
            signature_header=signature,
            event_header=event,
            payload=payload,
        )
        if not ok:
            return Response({'detail': message}, status=status.HTTP_400_BAD_REQUEST)
        return Response({'detail': message}, status=status.HTTP_200_OK)


@method_decorator(csrf_exempt, name='dispatch')
class MmAggregatorWebhookView(APIView):
    """Merchant webhook receiver for MM Aggregator deposit/payout status updates."""

    authentication_classes = []
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        raw = request.body
        try:
            payload = json.loads(raw.decode('utf-8') or '{}')
        except json.JSONDecodeError:
            return Response(
                {'detail': 'invalid_json'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        signature = (
            request.headers.get('X-Mma-Signature')
            or request.headers.get('X-Webhook-Signature')
            or ''
        )
        ok, message = handle_mm_aggregator_webhook(
            raw_body=raw,
            signature_header=signature,
            payload=payload,
        )
        if not ok:
            return Response({'detail': message}, status=status.HTTP_400_BAD_REQUEST)
        return Response({'detail': message}, status=status.HTTP_200_OK)


@method_decorator(csrf_exempt, name='dispatch')
class MainmoneyRedirectView(APIView):
    """Verify signed redirect query params, update ledger, bounce to the app."""

    authentication_classes = []
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        qp = request.query_params
        reference = qp.get('reference', '')
        pay_status = qp.get('status', '')
        amount = qp.get('amount', '')
        currency = qp.get('currency', '')
        timestamp = qp.get('timestamp', '')
        signature = qp.get('signature', '')

        ok, message = handle_redirect_callback(
            reference=reference,
            status=pay_status,
            amount=amount,
            currency=currency,
            timestamp=timestamp,
            signature=signature,
        )

        base = getattr(settings, 'PAYMENT_REDIRECT_BASE_URL', '').rstrip('/')
        dest = (
            f'{base}/payment-return'
            f'?reference={reference}&status={pay_status}&amount={amount}'
            f'&currency={currency}&timestamp={timestamp}'
            f'&verified={"1" if ok else "0"}&detail={message}'
        )
        return HttpResponseRedirect(dest)
