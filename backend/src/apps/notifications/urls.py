from django.urls import include, path
from rest_framework.routers import DefaultRouter

from src.apps.notifications.views import NotificationViewSet

router = DefaultRouter()
router.register('', NotificationViewSet, basename='notification')

urlpatterns = [
    path('', include(router.urls)),
]
