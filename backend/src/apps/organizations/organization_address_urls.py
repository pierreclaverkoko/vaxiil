from django.urls import path

from src.apps.organizations.organization_address_views import OrganizationAddressViewSet

organization_address_list = OrganizationAddressViewSet.as_view(
    {
        'get': 'list',
        'post': 'create',
    }
)
organization_address_detail = OrganizationAddressViewSet.as_view(
    {
        'get': 'retrieve',
        'put': 'update',
        'patch': 'partial_update',
        'delete': 'destroy',
    }
)

urlpatterns = [
    path('', organization_address_list, name='organization-addresses-list'),
    path(
        '<uuid:pk>/',
        organization_address_detail,
        name='organization-addresses-detail',
    ),
]
