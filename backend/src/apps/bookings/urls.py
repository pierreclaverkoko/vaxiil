from django.urls import include, path
from rest_framework.routers import DefaultRouter

from src.apps.bookings import views

router = DefaultRouter()
router.register('', views.BookingViewSet, basename='booking')

urlpatterns = [
    path('', include(router.urls)),
]
