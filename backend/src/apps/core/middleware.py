from django.db import models
from django.utils.deprecation import MiddlewareMixin

from src.apps.core.country_scope import country_iso2, resolve_country

RESOLVED_COUNTRY_HEADER = 'X-Resolved-Country'


class SoftDeleteMiddleware(MiddlewareMixin):
    def process_view(self, request, view_func, view_args, view_kwargs):
        if hasattr(request, 'user') and request.user.is_authenticated:
            if hasattr(request.user, 'organization'):
                request.organization = request.user.organization

        return None


class CountryScopeMiddleware(MiddlewareMixin):
    """Attach request.country and echo X-Resolved-Country on the response."""

    def process_request(self, request):
        request.country = resolve_country(request)
        return None

    def process_response(self, request, response):
        country = getattr(request, 'country', None)
        iso2 = country_iso2(country)
        if iso2:
            response[RESOLVED_COUNTRY_HEADER] = iso2
        return response


class OrganizationQuerysetMixin:
    def get_queryset(self):
        queryset = super().get_queryset()
        if hasattr(self.request, 'organization'):
            queryset = queryset.filter(organization=self.request.organization)
        return queryset


class UniqueConstraintWithSoftDelete:
    @classmethod
    def get_unique_constraints(cls, model_class):
        constraints = []
        
        for constraint in model_class._meta.constraints:
            if isinstance(constraint, models.UniqueConstraint):
                # Add condition to exclude soft-deleted records
                new_constraint = models.UniqueConstraint(
                    fields=constraint.fields,
                    condition=models.Q(deleted_at__isnull=True),
                    name=constraint.name
                )
                constraints.append(new_constraint)
            else:
                constraints.append(constraint)
        
        return constraints
