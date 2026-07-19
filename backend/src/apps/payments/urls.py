from django.urls import include, path
from rest_framework.routers import DefaultRouter

from src.apps.payments.views import (
    MainmoneyRedirectView,
    MainmoneyWebhookView,
    PaymentLinkViewSet,
)

router = DefaultRouter()
router.register(r'', PaymentLinkViewSet, basename='payments')

urlpatterns = [
    path(
        'webhooks/mainmoney/',
        MainmoneyWebhookView.as_view(),
        name='payments-webhook-mainmoney',
    ),
    path(
        'redirect/',
        MainmoneyRedirectView.as_view(),
        name='payments-redirect-mainmoney',
    ),
    path('', include(router.urls)),
]
