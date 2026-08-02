"""Read-only catalog viewsets for PaymentConnector / PaymentMethod."""

from __future__ import annotations

from django.db.models import Q
from rest_framework import permissions, viewsets

from src.apps.organizations.models import Country
from src.apps.payments.catalog import PaymentConnector, PaymentMethod
from src.apps.payments.catalog_serializers import (
    PaymentConnectorBriefSerializer,
    PaymentMethodSerializer,
)


class PaymentConnectorViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = PaymentConnectorBriefSerializer
    permission_classes = [permissions.IsAuthenticated]
    http_method_names = ['get', 'head', 'options']
    pagination_class = None

    def get_queryset(self):
        return PaymentConnector.objects.filter(is_active=True).order_by('code')


class PaymentMethodViewSet(viewsets.ReadOnlyModelViewSet):
    """Searchable payment rails. Filters: country, q, method_type, connector, operation."""

    serializer_class = PaymentMethodSerializer
    permission_classes = [permissions.IsAuthenticated]
    http_method_names = ['get', 'head', 'options']
    pagination_class = None

    def get_queryset(self):
        qs = (
            PaymentMethod.objects.filter(is_active=True)
            .select_related('connector', 'country', 'country__cities_country', 'currency')
            .order_by('name')
        )
        params = self.request.query_params

        operation = (params.get('operation') or '').strip()
        if operation:
            qs = qs.filter(supported_operations__contains=[operation])

        connector = (params.get('connector') or '').strip()
        if connector:
            qs = qs.filter(
                Q(connector__code__iexact=connector) | Q(connector_id=connector)
            )

        method_type = (params.get('method_type') or '').strip()
        if method_type:
            qs = qs.filter(method_type=method_type)

        country = (params.get('country') or '').strip()
        if country:
            org_country = Country.objects.filter(pk=country).first()
            if org_country:
                qs = qs.filter(Q(country=org_country) | Q(country__isnull=True))
            else:
                qs = qs.filter(
                    Q(country__cities_country__code__iexact=country)
                    | Q(country__isnull=True)
                )

        q = (params.get('q') or '').strip()
        if q:
            qs = qs.filter(
                Q(code__icontains=q)
                | Q(name__icontains=q)
                | Q(connector__code__icontains=q)
                | Q(connector__name__icontains=q)
            )
            return qs[:40]
        return qs[:100]
