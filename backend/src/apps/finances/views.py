from django.db.models import Q
from rest_framework import permissions, viewsets

from src.apps.finances.models import Currency
from src.apps.finances.serializers import CurrencySerializer


class CurrencyViewSet(viewsets.ReadOnlyModelViewSet):
    """List/detail currencies (reference data). Supports ?q= code/name search."""

    serializer_class = CurrencySerializer
    permission_classes = [permissions.AllowAny]
    http_method_names = ['get', 'head', 'options']
    pagination_class = None

    def get_queryset(self):
        qs = Currency.objects.filter(is_active=True).order_by('code')
        q = (self.request.query_params.get('q') or '').strip()
        if q:
            qs = qs.filter(Q(code__icontains=q) | Q(name__icontains=q))
            return qs[:20]
        return qs[:100]
