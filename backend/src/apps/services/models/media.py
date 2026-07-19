from django.db import models
from django.utils.translation import gettext_lazy as _

from src.apps.core.models import SoftDeleteModel


class ServiceMedia(SoftDeleteModel):
    """Media files for services."""

    class ServiceMediaType(models.TextChoices):
        IMAGE = 'I', _('Image')
        VIDEO = 'V', _('Video')
        DOCUMENT = 'D', _('Document')

    service = models.ForeignKey(
        'Service',
        on_delete=models.CASCADE,
        related_name='media',
    )
    media_type = models.CharField(
        max_length=1,
        choices=ServiceMediaType.choices,
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
        return f'{self.service.name} - {self.title}'
