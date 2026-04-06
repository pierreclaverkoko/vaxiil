from django.urls import path, include
from rest_framework.routers import DefaultRouter

from src.apps.finances.views import CurrencyViewSet

router = DefaultRouter()
router.register('currencies', CurrencyViewSet, basename='currency')

urlpatterns = [
    path('', include(router.urls)),
]
