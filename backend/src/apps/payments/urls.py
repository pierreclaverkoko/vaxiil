from django.urls import include, path
from rest_framework.routers import DefaultRouter

from src.apps.payments.views import (
    MainmoneyRedirectView,
    MainmoneyWebhookView,
    MmAggregatorWebhookView,
    PaymentLinkViewSet,
)
from src.apps.payments.catalog_views import PaymentConnectorViewSet, PaymentMethodViewSet

router = DefaultRouter()
router.register(r'connectors', PaymentConnectorViewSet, basename='payment-connectors')
router.register(r'methods', PaymentMethodViewSet, basename='payment-methods')
router.register(r'', PaymentLinkViewSet, basename='payments')

urlpatterns = [
    path(
        'webhooks/mainmoney/',
        MainmoneyWebhookView.as_view(),
        name='payments-webhook-mainmoney',
    ),
    path(
        'webhooks/mm_aggregator/',
        MmAggregatorWebhookView.as_view(),
        name='payments-webhook-mm-aggregator',
    ),
    path(
        'redirect/',
        MainmoneyRedirectView.as_view(),
        name='payments-redirect-mainmoney',
    ),
    path('', include(router.urls)),
]
