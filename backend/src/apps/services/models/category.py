from django.db import models
from src.apps.core.models import SoftDeleteModel


class ServiceCategory(SoftDeleteModel):
    """Service category model for organizing wellness services."""
    
    name = models.CharField(max_length=100, unique=True)
    description = models.TextField(blank=True)
    icon = models.CharField(
        max_length=50,
        blank=True,
        help_text=(
            'Heroicon name (kebab-case) matching the Flutter heroicons package, '
            'e.g. sparkles, heart, user.'
        ),
    )
    is_active = models.BooleanField(default=True)
    sort_order = models.PositiveIntegerField(default=0)
    
    class Meta:
        db_table = 'service_categories'
        ordering = ['sort_order', 'name']
        indexes = [
            models.Index(fields=['name']),
            models.Index(fields=['is_active']),
            models.Index(fields=['sort_order']),
        ]
    
    def __str__(self):
        return self.name


class ServiceSubCategory(SoftDeleteModel):
    """Service sub-category model for specific service types."""
    
    name = models.CharField(max_length=100)
    category = models.ForeignKey(
        ServiceCategory,
        on_delete=models.CASCADE,
        related_name='sub_categories'
    )
    description = models.TextField(blank=True)
    duration_options = models.JSONField(
        default=list,
        blank=True,
        help_text='List of available durations in minutes'
    )
    is_active = models.BooleanField(default=True)
    sort_order = models.PositiveIntegerField(default=0)
    
    class Meta:
        db_table = 'service_sub_categories'
        unique_together = [['name', 'category']]
        ordering = ['sort_order', 'name']
        indexes = [
            models.Index(fields=['category']),
            models.Index(fields=['name']),
            models.Index(fields=['is_active']),
            models.Index(fields=['sort_order']),
        ]
    
    def __str__(self):
        return f"{self.category.name} - {self.name}"
