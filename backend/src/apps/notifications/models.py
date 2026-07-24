import uuid

from django.conf import settings
from django.db import models
from django.utils.translation import gettext_lazy as _


class Notification(models.Model):
    """In-app notification persisted when booking lifecycle emails are sent."""

    class Kind(models.TextChoices):
        BOOKING_RECEIVED = 'booking_received', _('Booking received')
        BOOKING_CONFIRMED = 'booking_confirmed', _('Booking confirmed')
        RESCHEDULE_PROPOSED = 'reschedule_proposed', _('Reschedule proposed')
        RESCHEDULE_ACCEPTED = 'reschedule_accepted', _('Reschedule accepted')
        RESCHEDULE_DECLINED = 'reschedule_declined', _('Reschedule declined')
        BOOKING_CANCELLED = 'booking_cancelled', _('Booking cancelled')

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='notifications',
    )
    kind = models.CharField(max_length=32, choices=Kind.choices, db_index=True)
    title = models.CharField(max_length=255)
    body = models.TextField()
    booking = models.ForeignKey(
        'bookings.Booking',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='notifications',
    )
    read_at = models.DateTimeField(null=True, blank=True)
    email_sent_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'notifications'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', '-created_at']),
            models.Index(fields=['kind']),
        ]

    def __str__(self):
        return f'{self.kind} → {self.user_id}'
