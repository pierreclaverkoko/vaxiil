from django.db import models
from src.apps.core.models import SoftDeleteModel


class ServiceFeature(SoftDeleteModel):
    """Features and requirements for services."""

    class ServiceFeatureType(models.TextChoices):
        AMENITY = 'A', 'Amenity'
        REQUIREMENT = 'R', 'Requirement'
        SAFETY = 'S', 'Safety Feature'

    name = models.CharField(max_length=100)
    feature_type = models.CharField(
        max_length=1,
        choices=ServiceFeatureType.choices,
    )
    description = models.TextField(blank=True)
    icon = models.CharField(max_length=50, blank=True)

    class Meta:
        db_table = 'service_features'
        ordering = ['feature_type', 'name']
        indexes = [
            models.Index(fields=['feature_type']),
            models.Index(fields=['name']),
        ]

    _FEATURE_TYPE_CSS = {
        ServiceFeatureType.AMENITY.value: 'info',
        ServiceFeatureType.REQUIREMENT.value: 'warning',
        ServiceFeatureType.SAFETY.value: 'success',
    }

    def get_feature_type_css(self):
        return self._FEATURE_TYPE_CSS.get(self.feature_type, 'default')

    def __str__(self):
        return f'{self.get_feature_type_display()}: {self.name}'


class ServiceFeatureMapping(SoftDeleteModel):
    """Mapping between services and features."""

    service = models.ForeignKey(
        'Service',
        on_delete=models.CASCADE,
        related_name='feature_mappings',
    )
    feature = models.ForeignKey(
        ServiceFeature,
        on_delete=models.CASCADE,
        related_name='service_mappings',
    )
    is_required = models.BooleanField(default=False)

    class Meta:
        db_table = 'service_feature_mappings'
        unique_together = [['service', 'feature']]
        indexes = [
            models.Index(fields=['service']),
            models.Index(fields=['feature']),
            models.Index(fields=['is_required']),
        ]

    def __str__(self):
        return f'{self.service.name} - {self.feature.name}'
