from django.db import models
from django.core.validators import MinValueValidator, MaxValueValidator
from django.utils import timezone
from src.apps.core.models import SoftDeleteModel, OrganizationMixin


class CancellationPolicy(SoftDeleteModel, OrganizationMixin):
    class PolicyType(models.TextChoices):
        STRICT = 'S', 'Strict Policy'
        MODERATE = 'M', 'Moderate Policy'
        FLEXIBLE = 'F', 'Flexible Policy'
        CUSTOM = 'C', 'Custom Policy'

    organization = models.ForeignKey(
        'organizations.Organization',
        on_delete=models.CASCADE,
        related_name='cancellation_policies',
    )
    name = models.CharField(max_length=100)
    policy_type = models.CharField(
        max_length=1,
        choices=PolicyType.choices,
        default=PolicyType.MODERATE,
    )
    description = models.TextField()

    cancellation_windows = models.JSONField(
        default=dict,
        help_text='{"24": 0.1, "48": 0.5, "72": 0.75} - hours before = penalty percentage',
    )

    max_cancellation_hours = models.PositiveIntegerField(
        default=72,
        validators=[MinValueValidator(1), MaxValueValidator(168)],
    )

    full_refund_hours = models.PositiveIntegerField(
        default=48,
        help_text='Hours before booking for full refund',
    )
    partial_refund_percentage = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        default=50.0,
        validators=[MinValueValidator(0), MaxValueValidator(100)],
    )

    no_show_policy = models.TextField(
        default='No refund for no-shows',
        help_text='Policy for client no-shows',
    )
    emergency_cancellation = models.BooleanField(
        default=True,
        help_text='Allow emergency cancellations with full refund',
    )

    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'cancellation_policies'
        ordering = ['organization', 'name']

    def __str__(self):
        return f'{self.organization.name} - {self.name}'

    def calculate_penalty(self, hours_before_booking):
        if hours_before_booking >= self.full_refund_hours:
            return 0.0

        for window_hours, penalty in sorted(
            self.cancellation_windows.items(),
            key=lambda x: int(x[0]),
            reverse=True,
        ):
            if hours_before_booking >= int(window_hours):
                return float(penalty)

        return 100.0

    def get_refund_percentage(self, hours_before_booking):
        penalty = self.calculate_penalty(hours_before_booking)
        return max(0, 100 - penalty)


class CancellationRequest(SoftDeleteModel):
    class RequestStatus(models.TextChoices):
        PENDING = 'P', 'Pending Review'
        APPROVED = 'A', 'Approved'
        REJECTED = 'R', 'Rejected'
        PROCESSED = 'X', 'Processed'
        ESCALATED = 'E', 'Escalated'

    class ReasonType(models.TextChoices):
        CLIENT_REQUEST = 'C', 'Client Request'
        PRACTITIONER_REQUEST = 'P', 'Practitioner Request'
        SYSTEM_AUTO = 'S', 'System Automatic'
        EMERGENCY = 'E', 'Emergency'
        TECHNICAL = 'T', 'Technical Issue'
        WEATHER = 'W', 'Weather Related'
        OTHER = 'O', 'Other'

    booking = models.ForeignKey(
        'Booking',
        on_delete=models.CASCADE,
        related_name='cancellation_requests',
    )
    requested_by = models.ForeignKey(
        'users.User',
        on_delete=models.CASCADE,
        related_name='cancellation_requests_made',
    )

    reason_type = models.CharField(
        max_length=1,
        choices=ReasonType.choices,
        default=ReasonType.CLIENT_REQUEST,
    )
    reason = models.TextField()
    detailed_explanation = models.TextField(blank=True)

    status = models.CharField(
        max_length=1,
        choices=RequestStatus.choices,
        default=RequestStatus.PENDING,
    )
    processed_by = models.ForeignKey(
        'users.User',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='cancellation_requests_processed',
    )
    processing_notes = models.TextField(blank=True)

    refund_amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        null=True,
        blank=True,
        validators=[MinValueValidator(0)],
    )
    refund_percentage = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        null=True,
        blank=True,
        validators=[MinValueValidator(0), MaxValueValidator(100)],
    )
    refund_processed_at = models.DateTimeField(null=True, blank=True)

    requested_at = models.DateTimeField(auto_now_add=True)
    processed_at = models.DateTimeField(null=True, blank=True)

    supporting_documents = models.JSONField(
        default=list,
        blank=True,
        help_text='List of supporting document URLs or references',
    )

    class Meta:
        db_table = 'cancellation_requests'
        ordering = ['-requested_at']

    def __str__(self):
        return f'Cancellation Request {self.id} - Booking {self.booking.id}'

    def approve(self, processor, refund_amount=None, notes=''):
        self.status = self.RequestStatus.APPROVED
        self.processed_by = processor
        self.processing_notes = notes
        self.processed_at = timezone.now()

        if refund_amount is not None:
            self.refund_amount = refund_amount

        if self.refund_percentage is None and self.booking:
            hours_before = (
                self.processed_at - self.booking.confirmed_at
            ).total_seconds() / 3600
            policy = self.booking.organization.cancellation_policies.filter(
                is_active=True
            ).first()
            if policy:
                self.refund_percentage = policy.get_refund_percentage(hours_before)

        self.save()

    def reject(self, processor, reason=''):
        self.status = self.RequestStatus.REJECTED
        self.processed_by = processor
        self.processing_notes = reason
        self.processed_at = timezone.now()
        self.save()


class CancellationAuditLog(SoftDeleteModel):
    class ActionType(models.TextChoices):
        REQUEST_CREATED = 'C', 'Cancellation Request Created'
        REQUEST_APPROVED = 'A', 'Cancellation Request Approved'
        REQUEST_REJECTED = 'R', 'Cancellation Request Rejected'
        REFUND_PROCESSED = 'F', 'Refund Processed'
        POLICY_APPLIED = 'P', 'Cancellation Policy Applied'
        AUTOMATIC_CANCEL = 'X', 'Automatic Cancellation'
        MANUAL_OVERRIDE = 'M', 'Manual Override'

    booking = models.ForeignKey(
        'Booking',
        on_delete=models.CASCADE,
        related_name='cancellation_audit_logs',
    )
    cancellation_request = models.ForeignKey(
        CancellationRequest,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='audit_logs',
    )

    action_type = models.CharField(
        max_length=1,
        choices=ActionType.choices,
    )
    performed_by = models.ForeignKey(
        'users.User',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='cancellation_actions',
    )

    old_data = models.JSONField(
        default=dict,
        blank=True,
        help_text='Snapshot of data before action',
    )
    new_data = models.JSONField(
        default=dict,
        blank=True,
        help_text='Snapshot of data after action',
    )

    description = models.TextField()
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.TextField(blank=True)

    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'cancellation_audit_logs'
        ordering = ['-timestamp']

    def __str__(self):
        return f'{self.get_action_type_display()} - Booking {self.booking.id}'
