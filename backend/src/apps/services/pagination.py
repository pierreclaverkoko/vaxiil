from rest_framework.pagination import PageNumberPagination


class CatalogPagination(PageNumberPagination):
    """Allow clients to set `page_size` (capped) for the service catalog."""

    page_size = 20
    page_size_query_param = 'page_size'
    max_page_size = 100
