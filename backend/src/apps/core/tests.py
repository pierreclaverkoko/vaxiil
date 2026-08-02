from django.test import TestCase
from django.utils import timezone

from src.apps.core.models import SoftDeleteQuerySet, SoftDeleteManager, AvailabilityMixin
from src.apps.services.models.category import ServiceCategory


class SoftDeleteModelTests(TestCase):
    """Test SoftDeleteModel / SoftDeleteManager / SoftDeleteQuerySet."""

    def setUp(self):
        self.alive = ServiceCategory.objects.create(name='Alive Cat', sort_order=1)
        self.gone = ServiceCategory.objects.create(name='Gone Cat', sort_order=2)
        self.gone.deleted_at = timezone.now()
        self.gone.save(update_fields=['deleted_at', 'updated_at'])

    def test_default_manager_excludes_deleted(self):
        ids = set(ServiceCategory.objects.values_list('id', flat=True))
        self.assertIn(self.alive.id, ids)
        self.assertNotIn(self.gone.id, ids)

    def test_get_all_queryset_includes_deleted(self):
        ids = set(
            ServiceCategory.objects.get_all_queryset().values_list('id', flat=True)
        )
        self.assertIn(self.alive.id, ids)
        self.assertIn(self.gone.id, ids)

    def test_get_deleted_queryset_only_deleted(self):
        ids = set(
            ServiceCategory.objects.get_deleted_queryset().values_list('id', flat=True)
        )
        self.assertNotIn(self.alive.id, ids)
        self.assertIn(self.gone.id, ids)

    def test_queryset_is_soft_delete_queryset(self):
        self.assertIsInstance(ServiceCategory.objects.all(), SoftDeleteQuerySet)
        self.assertIsInstance(ServiceCategory.objects, SoftDeleteManager)

    def test_instance_soft_delete_and_restore(self):
        self.alive.delete()
        self.alive.refresh_from_db()
        self.assertTrue(self.alive.is_deleted)
        self.assertFalse(
            ServiceCategory.objects.filter(pk=self.alive.pk).exists()
        )

        self.alive.restore()
        self.alive.refresh_from_db()
        self.assertFalse(self.alive.is_deleted)
        self.assertTrue(
            ServiceCategory.objects.filter(pk=self.alive.pk).exists()
        )

    def test_queryset_soft_delete(self):
        ServiceCategory.objects.filter(pk=self.alive.pk).delete()
        self.assertFalse(
            ServiceCategory.objects.filter(pk=self.alive.pk).exists()
        )
        self.assertTrue(
            ServiceCategory.all_objects.filter(
                pk=self.alive.pk, deleted_at__isnull=False
            ).exists()
        )

    def test_queryset_restore(self):
        restored = ServiceCategory.objects.get_deleted_queryset().filter(
            pk=self.gone.pk
        ).restore()
        self.assertEqual(restored, 1)
        self.assertTrue(
            ServiceCategory.objects.filter(pk=self.gone.pk).exists()
        )

    def test_queryset_hard_delete(self):
        pk = self.gone.pk
        ServiceCategory.objects.get_all_queryset().filter(pk=pk).hard_delete()
        self.assertFalse(
            ServiceCategory.all_objects.filter(pk=pk).exists()
        )

    def test_instance_hard_delete(self):
        pk = self.alive.pk
        self.alive.hard_delete()
        self.assertFalse(
            ServiceCategory.all_objects.filter(pk=pk).exists()
        )


class AvailabilityMixinTests(TestCase):
    """Test cases for AvailabilityMixin."""

    def test_day_of_week_choices(self):
        """Test DayOfWeek choices."""
        days = [
            AvailabilityMixin.DayOfWeek.MONDAY,
            AvailabilityMixin.DayOfWeek.TUESDAY,
            AvailabilityMixin.DayOfWeek.WEDNESDAY,
            AvailabilityMixin.DayOfWeek.THURSDAY,
            AvailabilityMixin.DayOfWeek.FRIDAY,
            AvailabilityMixin.DayOfWeek.SATURDAY,
            AvailabilityMixin.DayOfWeek.SUNDAY,
        ]

        for day in days:
            self.assertIn(day, dict(AvailabilityMixin.DayOfWeek.choices).values())
            self.assertTrue(hasattr(day, 'label'))

    def test_default_available_days(self):
        """Test default available days setting."""
        # This would be tested with a concrete model that inherits AvailabilityMixin
        pass

    def test_availability_methods(self):
        """Test availability checking methods."""
        # This would be tested with a concrete model that inherits AvailabilityMixin
        pass
