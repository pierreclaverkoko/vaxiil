from django.urls import include, path
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register(r'categories', views.ServiceCategoryViewSet, basename='service-category')
router.register(
    r'subcategories',
    views.ServiceSubCategoryViewSet,
    basename='service-subcategory',
)
router.register(r'features', views.ServiceFeatureViewSet, basename='service-feature')
router.register(r'', views.ServiceCatalogViewSet, basename='service-catalog')

urlpatterns = [
    path('', include(router.urls)),
]
