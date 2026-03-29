from django.db import models
from django.core.validators import MinValueValidator, MaxValueValidator
from django.utils import timezone
from src.apps.core.models import SoftDeleteModel, OrganizationMixin


class CancellationPolicy(SoftDeleteModel, OrganizationMixin):
    POLICY_TYPES = [
        ('STRICT', 'Strict Policy'),
        ('MODERATE', 'Moderate Policy'),
        ('FLEXIBLE', 'Flexible Policy'),
        ('CUSTOM', 'Custom Policy'),
    ]
    
    organization = models.ForeignKey(
        'organizations.Organization',
        on_delete=models.CASCADE,
        related_name='cancellation_policies'
    )
    name = models.CharField(max_length=100)
    policy_type = models.CharField(
        max_length=10,
        choices=POLICY_TYPES,
        default='MODERATE'
    )
    description = models.TextField()
    
    # Time windows and penalties (in hours before booking)
    cancellation_windows = models.JSONField(
        default=dict,
        help_text='{"24": 0.1, "48": 0.5, "72": 0.75} - hours before = penalty percentage'
    )
    
    # Maximum cancellation time (hours before booking)
    max_cancellation_hours = models.PositiveIntegerField(
        default=72,
        validators=[MinValueValidator(1), MaxValueValidator(168)]
    )
    
    # Refund policies
    full_refund_hours = models.PositiveIntegerField(
        default=48,
        help_text='Hours before booking for full refund'
    )
    partial_refund_percentage = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        default=50.0,
        validators=[MinValueValidator(0), MaxValueValidator(100)]
    )
    
    # Special conditions
    no_show_policy = models.TextField(
        default='No refund for no-shows',
        help_text='Policy for client no-shows'
    )
    emergency_cancellation = models.BooleanField(
        default=True,
        help_text='Allow emergency cancellations with full refund'
    )
    
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'cancellation_policies'
        ordering = ['organization', 'name']
    
    def __str__(self):
        return f"{self.organization.name} - {self.name}"
    
    def calculate_penalty(self, hours_before_booking):
        """Calculate cancellation penalty based on hours before booking"""
        if hours_before_booking >= self.full_refund_hours:
            return 0.0
        
        # Check cancellation windows
        for window_hours, penalty in sorted(
            self.cancellation_windows.items(), 
            key=lambda x: int(x[0]), 
            reverse=True
        ):
            if hours_before_booking >= int(window_hours):
                return float(penalty)
        
        # Default to maximum penalty if no window matches
        return 100.0
    
    def get_refund_percentage(self, hours_before_booking):
        """Calculate refund percentage"""
        penalty = self.calculate_penalty(hours_before_booking)
        return max(0, 100 - penalty)


class CancellationRequest(SoftDeleteModel):
    REQUEST_STATUS = [
        ('PENDING', 'Pending Review'),
        ('APPROVED', 'Approved'),
        ('REJECTED', 'Rejected'),
        ('PROCESSED', 'Processed'),
        ('ESCALATED', 'Escalated'),
    ]
    
    REASON_TYPES = [
        ('CLIENT_REQUEST', 'Client Request'),
        ('PRACTITIONER_REQUEST', 'Practitioner Request'),
        ('SYSTEM_AUTO', 'System Automatic'),
        ('EMERGENCY', 'Emergency'),
        ('TECHNICAL', 'Technical Issue'),
        ('WEATHER', 'Weather Related'),
        ('OTHER', 'Other'),
    ]
    
    booking = models.ForeignKey(
        'Booking',
        on_delete=models.CASCADE,
        related_name='cancellation_requests'
    )
    requested_by = models.ForeignKey(
        'users.User',
        on_delete=models.CASCADE,
        related_name='cancellation_requests_made'
    )
    
    # Request details
    reason_type = models.CharField(
        max_length=20,
        choices=REASON_TYPES,
        default='CLIENT_REQUEST'
    )
    reason = models.TextField()
    detailed_explanation = models.TextField(blank=True)
    
    # Processing details
    status = models.CharField(
        max_length=20,
        choices=REQUEST_STATUS,
        default='PENDING'
    )
    processed_by = models.ForeignKey(
        'users.User',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='cancellation_requests_processed'
    )
    processing_notes = models.TextField(blank=True)
    
    # Financial details
    refund_amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        null=True,
        blank=True,
        validators=[MinValueValidator(0)]
    )
    refund_percentage = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        null=True,
        blank=True,
        validators=[MinValueValidator(0), MaxValueValidator(100)]
    )
    refund_processed_at = models.DateTimeField(null=True, blank=True)
    
    # Timestamps
    requested_at = models.DateTimeField(auto_now_add=True)
    processed_at = models.DateTimeField(null=True, blank=True)
    
    # Evidence/Documentation
    supporting_documents = models.JSONField(
        default=list,
        blank=True,
        help_text='List of supporting document URLs or references'
    )
    
    class Meta:
        db_table = 'cancellation_requests'
        ordering = ['-requested_at']
    
    def __str__(self):
        return f"Cancellation Request {self.id} - Booking {self.booking.id}"
    
    def approve(self, processor, refund_amount=None, notes=''):
        """Approve cancellation request"""
        self.status = 'APPROVED'
        self.processed_by = processor
        self.processing_notes = notes
        self.processed_at = timezone.now()
        
        if refund_amount is not None:
            self.refund_amount = refund_amount
        
        # Calculate refund percentage if not provided
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
        """Reject cancellation request"""
        self.status = 'REJECTED'
        self.processed_by = processor
        self.processing_notes = reason
        self.processed_at = timezone.now()
        self.save()


class CancellationAuditLog(SoftDeleteModel):
    """Audit trail for all cancellation-related actions"""
    ACTION_TYPES = [
        ('REQUEST_CREATED', 'Cancellation Request Created'),
        ('REQUEST_APPROVED', 'Cancellation Request Approved'),
        ('REQUEST_REJECTED', 'Cancellation Request Rejected'),
        ('REFUND_PROCESSED', 'Refund Processed'),
        ('POLICY_APPLIED', 'Cancellation Policy Applied'),
        ('AUTOMATIC_CANCEL', 'Automatic Cancellation'),
        ('MANUAL_OVERRIDE', 'Manual Override'),
    ]
    
    booking = models.ForeignKey(
        'Booking',
        on_delete=models.CASCADE,
        related_name='cancellation_audit_logs'
    )
    cancellation_request = models.ForeignKey(
        CancellationRequest,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='audit_logs'
    )
    
    # Action details
    action_type = models.CharField(
        max_length=25,
        choices=ACTION_TYPES
    )
    performed_by = models.ForeignKey(
        'users.User',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='cancellation_actions'
    )
    
    # Data before action
    old_data = models.JSONField(
        default=dict,
        blank=True,
        help_text='Snapshot of data before action'
    )
    new_data = models.JSONField(
        default=dict,
        blank=True,
        help_text='Snapshot of data after action'
    )
    
    # Action details
    description = models.TextField()
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.TextField(blank=True)
    
    # Timestamp
    timestamp = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        db_table = 'cancellation_audit_logs'
        ordering = ['-timestamp']
    
    def __str__(self):
        return f"{self.get_action_type_display()} - Booking {self.booking.id}"
