from django.urls import include, path
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register(r'countries', views.CountryViewSet, basename='country')
router.register(r'cities', views.CityViewSet, basename='city')
router.register(
    r'accepted-currencies',
    views.CountryAcceptedCurrencyViewSet,
    basename='accepted-currency',
)
router.register(r'types', views.OrganizationTypeViewSet, basename='organization-type')
router.register(r'', views.OrganizationViewSet, basename='organization')

urlpatterns = [
    path('', include(router.urls)),
    path(
        '<uuid:organization_pk>/addresses/',
        include('src.apps.organizations.organization_address_urls'),
    ),
    path(
        '<uuid:organization_pk>/services/',
        include('src.apps.services.organization_urls'),
    ),
]
