import uuid

from django.conf import settings
from django.db import models
from django.utils.translation import gettext_lazy as _


class EmailOtp(models.Model):
    """Short-lived email one-time codes for login 2FA and password flows."""

    class Purpose(models.TextChoices):
        LOGIN = 'L', _('Login')
        PASSWORD_CHANGE = 'C', _('Password change')
        PASSWORD_RESET = 'R', _('Password reset')
        EMAIL_VERIFY = 'E', _('Email verification')

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='email_otps',
        null=True,
        blank=True,
    )
    email = models.EmailField()
    purpose = models.CharField(max_length=1, choices=Purpose.choices)
    code_hash = models.CharField(max_length=128)
    expires_at = models.DateTimeField()
    attempts = models.PositiveSmallIntegerField(default=0)
    consumed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'email_otps'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['email', 'purpose', '-created_at']),
        ]

    def __str__(self):
        return f'{self.purpose} {self.email} ({self.id})'
