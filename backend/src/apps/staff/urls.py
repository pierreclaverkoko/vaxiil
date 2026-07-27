from django.urls import include, path
from rest_framework.routers import DefaultRouter

from src.apps.staff import views

router = DefaultRouter()
router.register(r'users', views.StaffUserVerificationViewSet, basename='staff-users')
router.register(
    r'organizations',
    views.StaffOrganizationVerificationViewSet,
    basename='staff-organizations',
)
router.register(
    r'taxonomy/categories',
    views.StaffServiceCategoryViewSet,
    basename='staff-categories',
)
router.register(
    r'taxonomy/subcategories',
    views.StaffServiceSubCategoryViewSet,
    basename='staff-subcategories',
)
router.register(
    r'taxonomy/features',
    views.StaffServiceFeatureViewSet,
    basename='staff-features',
)
router.register(
    r'payments',
    views.StaffPaymentTransactionViewSet,
    basename='staff-payments',
)
router.register(
    r'fees/categories',
    views.StaffCategoryPlatformFeeViewSet,
    basename='staff-fee-categories',
)
router.register(
    r'fees',
    views.StaffPlatformFeeEntryViewSet,
    basename='staff-fees',
)
router.register(
    r'fx-rates',
    views.StaffCurrencyFxRateViewSet,
    basename='staff-fx-rates',
)
router.register(
    r'settlements',
    views.StaffSettlementRequestViewSet,
    basename='staff-settlements',
)

urlpatterns = [
    path(
        'overview/',
        views.StaffOverviewView.as_view(),
        name='staff-overview',
    ),
    path(
        'platform-settings/',
        views.StaffPlatformSettingsView.as_view(),
        name='staff-platform-settings',
    ),
    path(
        'organizations/<uuid:pk>/fee-settings/',
        views.StaffOrganizationFeeSettingsView.as_view(),
        name='staff-organization-fee-settings',
    ),
    path('', include(router.urls)),
]
