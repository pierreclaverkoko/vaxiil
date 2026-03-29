from django.db import models
from src.apps.core.models import SoftDeleteModel


class ServiceMediaType(models.TextChoices):
    """Service media types."""
    IMAGE = 'IMAGE', 'Image'
    VIDEO = 'VIDEO', 'Video'
    DOCUMENT = 'DOCUMENT', 'Document'


class ServiceMedia(SoftDeleteModel):
    """Media files for services."""
    
    service = models.ForeignKey(
        'Service',
        on_delete=models.CASCADE,
        related_name='media'
    )
    media_type = models.CharField(
        max_length=10,
        choices=ServiceMediaType.choices
    )
    file = models.FileField(upload_to='service_media/')
    title = models.CharField(max_length=255, blank=True)
    description = models.TextField(blank=True)
    sort_order = models.PositiveIntegerField(default=0)
    is_primary = models.BooleanField(default=False)
    
    class Meta:
        db_table = 'service_media'
        ordering = ['sort_order']
        indexes = [
            models.Index(fields=['service']),
            models.Index(fields=['media_type']),
            models.Index(fields=['is_primary']),
            models.Index(fields=['sort_order']),
        ]
    
    def __str__(self):
        return f"{self.service.name} - {self.title}"
