from django.contrib.gis.db.models import PointField
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
    # WGS84 point; geography=True for correct spherical distance queries (PostGIS).
    location = PointField(srid=4326, geography=True, null=True, blank=True)

    class Meta:
        db_table = 'organization_addresses'
        ordering = ['-is_primary', 'created_at']
        indexes = [
            models.Index(fields=['organization']),
            models.Index(fields=['is_primary']),
        ]

    def __str__(self):
        return f'{self.organization.name} — {self.address}'

    def save(self, *args, **kwargs):
        self._sync_location_from_coordinates()
        super().save(*args, **kwargs)

    def _sync_location_from_coordinates(self):
        """Keep GeoDjango `location` in sync with decimal lat/lng."""
        from django.contrib.gis.geos import Point

        if self.latitude is not None and self.longitude is not None:
            self.location = Point(
                float(self.longitude),
                float(self.latitude),
                srid=4326,
            )
        else:
            self.location = None
