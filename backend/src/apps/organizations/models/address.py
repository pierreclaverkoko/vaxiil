from django.db import models

from src.apps.core.models import SoftDeleteModel, LocationModel

from .organization import Organization


class OrganizationAddress(SoftDeleteModel, LocationModel):
    """One or more physical addresses for an organization."""

    organization = models.ForeignKey(
        Organization,
        on_delete=models.CASCADE,
        related_name='addresses',
    )
    label = models.CharField(max_length=128, blank=True)
    is_primary = models.BooleanField(default=False)

    class Meta:
        db_table = 'organization_addresses'
        ordering = ['-is_primary', 'created_at']
        indexes = [
            models.Index(fields=['organization']),
            models.Index(fields=['is_primary']),
        ]

    def __str__(self):
        return f'{self.organization.name} — {self.address}'
