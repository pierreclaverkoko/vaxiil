import uuid
from decimal import Decimal

from django.conf import settings
from django.core.validators import MinValueValidator
from django.db import models
from django.utils.translation import gettext_lazy as _


class UserPlatformCharge(models.Model):
    """One-time (or future) platform charges billed to a user on booking payment."""

    class Kind(models.TextChoices):
        INSCRIPTION = 'I', _('Verification / inscription fee')

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='platform_charges',
    )
    kind = models.CharField(max_length=1, choices=Kind.choices)
    amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        validators=[MinValueValidator(Decimal('0'))],
    )
    usd_amount = models.DecimalField(max_digits=12, decimal_places=2)
    currency = models.ForeignKey(
        'finances.Currency',
        on_delete=models.PROTECT,
        related_name='user_platform_charges',
    )
    booking = models.ForeignKey(
        'bookings.Booking',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='user_platform_charges',
    )
    payment_transaction = models.ForeignKey(
        'payments.PaymentTransaction',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='user_platform_charges',
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'user_platform_charges'
        ordering = ['-created_at']
        constraints = [
            models.UniqueConstraint(
                fields=['user', 'kind'],
                condition=models.Q(kind='I'),
                name='unique_user_inscription_charge',
            ),
        ]

    def __str__(self):
        return f'{self.kind} {self.amount} {self.currency_id} user={self.user_id}'
