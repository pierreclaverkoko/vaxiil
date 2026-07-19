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
from src.apps.payments.services.payment_links import (
    create_payment_link_for_booking,
    create_wallet_top_up_link,
)
from src.apps.payments.services.wallet import wallet_summary_for
from src.apps.payments.services.webhooks import (
    handle_mainmoney_webhook,
    handle_redirect_callback,
)


class PaymentLinkViewSet(viewsets.ViewSet):
    """Authenticated payment-link creation for bookings."""

    permission_classes = [permissions.IsAuthenticated]

    @action(detail=False, methods=['get'], url_path='wallet')
    def wallet(self, request):
        return Response(wallet_summary_for(request.user), status=status.HTTP_200_OK)

    @action(detail=False, methods=['post'], url_path='wallet/top-up')
    def wallet_top_up(self, request):
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
        redirect_url = request.build_absolute_uri('/api/v1/payments/redirect/')
        result = create_wallet_top_up_link(
            user=request.user,
            amount=amount,
            currency_code=currency_code,
            redirect_url=redirect_url,
        )
        return Response(
            {
                'url': result.url,
                'merchant_reference': result.merchant_reference,
                'transaction_id': result.transaction_id,
                'amount': str(result.amount),
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
        redirect_url = request.build_absolute_uri('/api/v1/payments/redirect/')
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
        result = create_payment_link_for_booking(
            booking=booking,
            user=request.user,
            redirect_url=redirect_url,
            apply_wallet=apply_wallet,
            wallet_amount=wallet_amount,
        )
        return Response(
            {
                'url': result.url,
                'merchant_reference': result.merchant_reference,
                'transaction_id': result.transaction_id,
                'amount_charged': str(result.amount_charged),
                'wallet_applied': str(result.wallet_applied),
                'fully_paid': result.fully_paid,
            },
            status=status.HTTP_201_CREATED,
        )

    @action(
        detail=False,
        methods=['get'],
        url_path=r'transactions/(?P<client_reference>[^/.]+)',
    )
    def transaction_status(self, request, client_reference=None):
        txn = (
            PaymentTransaction.objects.filter(
                client_reference=client_reference,
                user=request.user,
            )
            .order_by('-created_at')
            .first()
        )
        if txn is None:
            return Response({'detail': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)
        return Response(
            {
                'transaction_id': str(txn.id),
                'client_reference': txn.client_reference,
                'status': txn.status,
                'booking_id': str(txn.booking_id) if txn.booking_id else None,
                'purpose': txn.purpose,
                'amount': str(txn.amount),
            }
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
        # Forward the same params (minus signature) so the app can show UX.
        dest = (
            f'{base}/payment-return'
            f'?reference={reference}&status={pay_status}&amount={amount}'
            f'&currency={currency}&timestamp={timestamp}'
            f'&verified={"1" if ok else "0"}&detail={message}'
        )
        return HttpResponseRedirect(dest)
