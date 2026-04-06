import django_filters

from src.apps.services.models import Service


class ServiceCatalogFilter(django_filters.FilterSet):
    """Query params for the public service catalog."""

    sub_category = django_filters.UUIDFilter(field_name='sub_category_id')
    category = django_filters.UUIDFilter(field_name='sub_category__category_id')

    class Meta:
        model = Service
        fields = ['featured', 'sub_category', 'category']
