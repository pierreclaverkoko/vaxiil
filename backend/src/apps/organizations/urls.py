from django.urls import include, path
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register(r'types', views.OrganizationTypeViewSet, basename='organization-type')
router.register(r'', views.OrganizationViewSet, basename='organization')

urlpatterns = [
    path('', include(router.urls)),
]
