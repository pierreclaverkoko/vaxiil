from rest_framework import permissions, viewsets

from src.apps.finances.models import Currency
from src.apps.finances.serializers import CurrencySerializer


class CurrencyViewSet(viewsets.ReadOnlyModelViewSet):
    """List/detail currencies (reference data)."""

    queryset = Currency.objects.filter(is_active=True).order_by('code')
    serializer_class = CurrencySerializer
    permission_classes = [permissions.AllowAny]
