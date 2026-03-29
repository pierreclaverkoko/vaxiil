from django.utils.deprecation import MiddlewareMixin
from django.db import models


class SoftDeleteMiddleware(MiddlewareMixin):
    def process_view(self, request, view_func, view_args, view_kwargs):
        if hasattr(request, 'user') and request.user.is_authenticated:
            if hasattr(request.user, 'organization'):
                request.organization = request.user.organization
        
        return None


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
