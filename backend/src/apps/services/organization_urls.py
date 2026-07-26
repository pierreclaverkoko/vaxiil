from django.urls import path

from src.apps.services.organization_views import OrganizationServiceViewSet

organization_service_list = OrganizationServiceViewSet.as_view({
    'get': 'list',
    'post': 'create',
})
organization_service_detail = OrganizationServiceViewSet.as_view({
    'get': 'retrieve',
    'put': 'update',
    'patch': 'partial_update',
    'delete': 'destroy',
})
organization_service_media = OrganizationServiceViewSet.as_view({
    'post': 'upload_media',
})

urlpatterns = [
    path('', organization_service_list, name='organization-services-list'),
    path('<uuid:pk>/', organization_service_detail, name='organization-services-detail'),
    path(
        '<uuid:pk>/media/',
        organization_service_media,
        name='organization-services-media',
    ),
]
