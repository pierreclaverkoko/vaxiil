from django.core.validators import MinValueValidator
from django.db import models
from django.utils import timezone
from django.utils.translation import gettext_lazy as _

from src.apps.core.models import AuditedModelMixin, OrganizationMixin, SoftDeleteModel


class BusinessHours(SoftDeleteModel):
    """Organization business hours."""

    class Weekday(models.IntegerChoices):
        MONDAY = 0, _('Monday')
        TUESDAY = 1, _('Tuesday')
        WEDNESDAY = 2, _('Wednesday')
        THURSDAY = 3, _('Thursday')
        FRIDAY = 4, _('Friday')
        SATURDAY = 5, _('Saturday')
        SUNDAY = 6, _('Sunday')

    organization = models.ForeignKey(
        'organizations.Organization',
        on_delete=models.CASCADE,
        related_name='business_hours',
    )
    day_of_week = models.PositiveSmallIntegerField(choices=Weekday.choices)
    open_time = models.TimeField()
    close_time = models.TimeField()
    is_closed = models.BooleanField(default=False)

    class Meta:
        db_table = 'business_hours'
        unique_together = [['organization', 'day_of_week']]
        ordering = ['day_of_week']
        indexes = [
            models.Index(fields=['organization']),
            models.Index(fields=['day_of_week']),
        ]

    def __str__(self):
        day_name = dict(self.Weekday.choices).get(self.day_of_week, 'Unknown')
        return f'{self.organization.name} - {day_name}'


class AvailabilityException(SoftDeleteModel):
    """Organization availability exceptions."""

    class ExceptionType(models.TextChoices):
        HOLIDAY = 'H', _('Holiday')
        MAINTENANCE = 'M', _('Maintenance')
        PRIVATE_EVENT = 'P', _('Private Event')
        WEATHER = 'W', _('Weather Related')
        OTHER = 'O', _('Other')

    organization = models.ForeignKey(
        'organizations.Organization',
        on_delete=models.CASCADE,
        related_name='availability_exceptions',
    )
    date = models.DateField()
    reason = models.CharField(max_length=255)
    exception_type = models.CharField(
        max_length=1,
        choices=ExceptionType.choices,
        default=ExceptionType.OTHER,
    )
    is_closed = models.BooleanField(default=True)
    alternate_hours = models.JSONField(
        default=dict,
        blank=True,
        help_text='Alternative hours for this date',
    )

    class Meta:
        db_table = 'availability_exceptions'
        ordering = ['date']
        indexes = [
            models.Index(fields=['organization']),
            models.Index(fields=['date']),
            models.Index(fields=['exception_type']),
        ]

    def __str__(self):
        return f'{self.organization.name} - {self.date} ({self.reason})'


class PractitionerAvailability(SoftDeleteModel):
    """Practitioner availability schedule."""

    class LocationType(models.TextChoices):
        OFFICE = 'O', _('At Office/Business Location')
        HOME = 'H', _('At Client Home')
        VIRTUAL = 'V', _('Virtual/Online')
        MOBILE = 'B', _('Mobile Service')

    user = models.ForeignKey(
        'users.User',
        on_delete=models.CASCADE,
        related_name='practitioner_availability',
    )
    date = models.DateField()
    time_slots = models.JSONField(
        default=list,
        help_text='List of available time slots [{"start": "09:00", "end": "10:30"}]',
    )
    max_bookings = models.PositiveIntegerField(
        default=1,
        validators=[MinValueValidator(1)],
    )
    location_type = models.CharField(
        max_length=1,
        choices=LocationType.choices,
        default=LocationType.OFFICE,
    )
    notes = models.TextField(blank=True)

    class Meta:
        db_table = 'practitioner_availability'
        unique_together = [['user', 'date']]
        ordering = ['-date']
        indexes = [
            models.Index(fields=['user']),
            models.Index(fields=['date']),
            models.Index(fields=['location_type']),
        ]

    def __str__(self):
        return f'{self.user.email} - {self.date}'


class ResourceAvailability(SoftDeleteModel):
    """Resource availability for bookings."""

    class ResourceType(models.TextChoices):
        ROOM = 'R', _('Room')
        EQUIPMENT = 'E', _('Equipment')
        FACILITY = 'F', _('Facility')

    organization = models.ForeignKey(
        'organizations.Organization',
        on_delete=models.CASCADE,
        related_name='resource_availability',
    )
    name = models.CharField(max_length=255)
    resource_type = models.CharField(
        max_length=1,
        choices=ResourceType.choices,
    )
    date = models.DateField()
    time_slots = models.JSONField(
        default=list,
        help_text='List of available time slots [{"start": "09:00", "end": "10:30"}]',
    )
    capacity = models.PositiveIntegerField(
        default=1,
        validators=[MinValueValidator(1)],
    )
    location_details = models.JSONField(
        default=dict,
        blank=True,
        help_text='Location details like room number, floor, etc.',
    )

    class Meta:
        db_table = 'resource_availability'
        unique_together = [['organization', 'name', 'date']]
        ordering = ['-date', 'resource_type', 'name']
        indexes = [
            models.Index(fields=['organization']),
            models.Index(fields=['date']),
            models.Index(fields=['resource_type']),
            models.Index(fields=['name']),
        ]

    def __str__(self):
        return f'{self.organization.name} - {self.name} ({self.date})'


class Booking(SoftDeleteModel, OrganizationMixin):
    """Main booking model."""

    class BookingStatus(models.TextChoices):
        DRAFT = 'D', _('Draft')
        REQUESTED = 'Q', _('Requested')
        CONFIRMED = 'F', _('Confirmed')
        IN_PROGRESS = 'P', _('In Progress')
        COMPLETED = 'M', _('Completed')
        CANCELLED = 'X', _('Cancelled')
        NO_SHOW = 'N', _('No Show')
        RESCHEDULED = 'R', _('Rescheduled')

    class LocationType(models.TextChoices):
        OFFICE = 'O', _('At Office/Business Location')
        HOME = 'H', _('At Client Home')
        VIRTUAL = 'V', _('Virtual/Online')
        MOBILE = 'B', _('Mobile Service')

    class PlatformFeePayer(models.TextChoices):
        CLIENT = 'C', _('Client')
        BUSINESS = 'B', _('Business')

    class PlatformFeeSource(models.TextChoices):
        GLOBAL = 'G', _('Global')
        CATEGORY = 'C', _('Category')
        ORGANIZATION = 'O', _('Organization')

    _STATUS_CSS = {
        BookingStatus.DRAFT.value: 'secondary',
        BookingStatus.REQUESTED.value: 'warning',
        BookingStatus.CONFIRMED.value: 'success',
        BookingStatus.IN_PROGRESS.value: 'info',
        BookingStatus.COMPLETED.value: 'primary',
        BookingStatus.CANCELLED.value: 'warning',
        BookingStatus.NO_SHOW.value: 'danger',
        BookingStatus.RESCHEDULED.value: 'warning',
    }
    _FEE_PAYER_CSS = {
        PlatformFeePayer.CLIENT.value: 'info',
        PlatformFeePayer.BUSINESS.value: 'warning',
    }
    _FEE_SOURCE_CSS = {
        PlatformFeeSource.GLOBAL.value: 'secondary',
        PlatformFeeSource.CATEGORY.value: 'info',
        PlatformFeeSource.ORGANIZATION.value: 'primary',
    }

    user = models.ForeignKey(
        'users.User',
        on_delete=models.CASCADE,
        related_name='bookings',
    )
    service = models.ForeignKey(
        'services.Service',
        on_delete=models.CASCADE,
        related_name='bookings',
    )
    organization = models.ForeignKey(
        'organizations.Organization',
        on_delete=models.CASCADE,
        related_name='bookings',
    )
    practitioner = models.ForeignKey(
        'users.User',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='practitioner_bookings',
    )
    status = models.CharField(
        max_length=1,
        choices=BookingStatus.choices,
        default=BookingStatus.DRAFT,
    )
    practitioner_alias = models.CharField(
        max_length=100,
        blank=True,
        help_text='Alias for practitioner when user requests specific person',
    )
    service_variant = models.ForeignKey(
        'services.ServiceVariantModel',
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name='bookings',
    )
    accepted_currency = models.ForeignKey(
        'organizations.CountryAcceptedCurrency',
        on_delete=models.PROTECT,
        related_name='bookings',
        null=True,
        blank=True,
    )
    total_price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        validators=[MinValueValidator(0)],
        help_text='Amount the client owes (base + fee when client pays the platform fee).',
    )
    base_price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        validators=[MinValueValidator(0)],
        default=0,
        help_text='Catalog/service price before platform fee.',
    )
    platform_fee_rate = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        default=0,
        validators=[MinValueValidator(0)],
        help_text='Snapshot of platform fee percent at booking time.',
    )
    platform_fee_amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0,
        validators=[MinValueValidator(0)],
    )
    platform_fee_payer = models.CharField(
        max_length=1,
        choices=PlatformFeePayer.choices,
        default=PlatformFeePayer.CLIENT,
        help_text='Who pays the platform fee (snapshot at booking time).',
    )
    platform_fee_source = models.CharField(
        max_length=1,
        choices=PlatformFeeSource.choices,
        default=PlatformFeeSource.GLOBAL,
        help_text='Where the fee rate was resolved from (snapshot).',
    )
    inscription_fee_amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0,
        validators=[MinValueValidator(0)],
        help_text='One-time verification fee included in client charge when due (snapshot).',
    )
    special_requests = models.TextField(blank=True)
    internal_notes = models.TextField(blank=True)
    share_name = models.BooleanField(default=False)
    share_phone = models.BooleanField(default=False)
    share_email = models.BooleanField(default=False)
    confirmed_at = models.DateTimeField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    cancelled_at = models.DateTimeField(null=True, blank=True)
    cancellation_reason = models.TextField(blank=True)

    class Meta:
        db_table = 'bookings'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user']),
            models.Index(fields=['service']),
            models.Index(fields=['organization']),
            models.Index(fields=['practitioner']),
            models.Index(fields=['status']),
            models.Index(fields=['created_at']),
            models.Index(fields=['confirmed_at']),
            models.Index(fields=['deleted_at']),
        ]

    def __str__(self):
        return f'Booking {self.id} - {self.user.email} - {self.service.name}'

    def get_status_css(self):
        return self._STATUS_CSS.get(self.status, 'default')

    def get_platform_fee_payer_css(self):
        return self._FEE_PAYER_CSS.get(self.platform_fee_payer, 'default')

    def get_platform_fee_source_css(self):
        return self._FEE_SOURCE_CSS.get(self.platform_fee_source, 'default')

    def earliest_slot_start(self):
        """Earliest active time-slot start, or None if the booking has no slots."""
        return (
            self.time_slots.filter(deleted_at__isnull=True)
            .order_by('start_time')
            .values_list('start_time', flat=True)
            .first()
        )

    def confirm(self):
        self.status = self.BookingStatus.CONFIRMED
        self.confirmed_at = timezone.now()
        self.save()

    def complete(self):
        self.status = self.BookingStatus.COMPLETED
        self.completed_at = timezone.now()
        self.save()

    def cancel(self, reason=''):
        self.status = self.BookingStatus.CANCELLED
        self.cancelled_at = timezone.now()
        self.cancellation_reason = reason
        self.save()


class BookingTimeSlot(SoftDeleteModel):
    """Individual time slots for bookings."""

    booking = models.ForeignKey(
        Booking,
        on_delete=models.CASCADE,
        related_name='time_slots',
    )
    start_time = models.DateTimeField()
    end_time = models.DateTimeField()
    location_type = models.CharField(
        max_length=1,
        choices=Booking.LocationType.choices,
        default=Booking.LocationType.OFFICE,
    )
    address = models.CharField(max_length=255, blank=True)
    room_details = models.CharField(max_length=255, blank=True)
    virtual_meeting_link = models.URLField(blank=True)
    notes = models.TextField(blank=True)

    class Meta:
        db_table = 'booking_time_slots'
        ordering = ['start_time']
        indexes = [
            models.Index(fields=['booking']),
            models.Index(fields=['start_time']),
            models.Index(fields=['end_time']),
            models.Index(fields=['location_type']),
        ]

    def __str__(self):
        return f'{self.booking.id} - {self.start_time} to {self.end_time}'


class BookingLog(SoftDeleteModel):
    """Audit log for booking status changes."""

    booking = models.ForeignKey(
        Booking,
        on_delete=models.CASCADE,
        related_name='logs',
    )
    old_status = models.CharField(
        max_length=1,
        choices=Booking.BookingStatus.choices,
        blank=True,
    )
    new_status = models.CharField(
        max_length=1,
        choices=Booking.BookingStatus.choices,
    )
    changed_by = models.ForeignKey(
        'users.User',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='booking_changes',
    )
    notes = models.TextField(blank=True)
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'booking_logs'
        ordering = ['-timestamp']
        indexes = [
            models.Index(fields=['booking']),
            models.Index(fields=['changed_by']),
            models.Index(fields=['timestamp']),
            models.Index(fields=['new_status']),
        ]

    def __str__(self):
        return f'Booking {self.booking.id} - {self.old_status} to {self.new_status}'


class BookingRescheduleProposal(SoftDeleteModel):
    """Pending counterparty decision for a proposed new schedule."""

    class ProposedBy(models.TextChoices):
        CLIENT = 'C', _('Client')
        BUSINESS = 'B', _('Business')

    class ProposalStatus(models.TextChoices):
        PENDING = 'P', _('Pending')
        ACCEPTED = 'A', _('Accepted')
        DECLINED = 'D', _('Declined')

    _PROPOSED_BY_CSS = {
        ProposedBy.CLIENT.value: 'info',
        ProposedBy.BUSINESS.value: 'primary',
    }
    _PROPOSAL_STATUS_CSS = {
        ProposalStatus.PENDING.value: 'warning',
        ProposalStatus.ACCEPTED.value: 'success',
        ProposalStatus.DECLINED.value: 'danger',
    }

    booking = models.ForeignKey(
        Booking,
        on_delete=models.CASCADE,
        related_name='reschedule_proposals',
    )
    proposed_by = models.CharField(max_length=1, choices=ProposedBy.choices)
    proposed_by_user = models.ForeignKey(
        'users.User',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='reschedule_proposals',
    )
    status = models.CharField(
        max_length=1,
        choices=ProposalStatus.choices,
        default=ProposalStatus.PENDING,
    )
    time_slots = models.JSONField(
        default=list,
        help_text='Proposed slots as list of dicts (start_time, end_time, location_type, …).',
    )
    reason = models.TextField(blank=True)
    decided_at = models.DateTimeField(null=True, blank=True)
    decided_by = models.ForeignKey(
        'users.User',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='reschedule_decisions',
    )

    class Meta:
        db_table = 'booking_reschedule_proposals'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['booking']),
            models.Index(fields=['status']),
        ]

    def get_proposed_by_css(self):
        return self._PROPOSED_BY_CSS.get(self.proposed_by, 'default')

    def get_status_css(self):
        return self._PROPOSAL_STATUS_CSS.get(self.status, 'default')

    def __str__(self):
        return f'Reschedule {self.booking_id} ({self.status})'


class BookingActionLog(AuditedModelMixin, SoftDeleteModel):
    """Lifecycle audit row for booking status mutations."""

    booking = models.ForeignKey(
        Booking,
        on_delete=models.CASCADE,
        related_name='action_logs',
    )
    action = models.CharField(max_length=64, db_index=True)
    performed_by = models.ForeignKey(
        'users.User',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='booking_action_logs',
    )
    description = models.TextField(blank=True)
    old_data = models.JSONField(default=dict, blank=True)
    new_data = models.JSONField(default=dict, blank=True)

    class Meta:
        db_table = 'booking_action_logs'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['booking', 'created_at']),
            models.Index(fields=['action']),
        ]

    def __str__(self):
        return f'{self.action} - Booking {self.booking_id}'


def record_booking_action(
    *,
    booking,
    action: str,
    performed_by=None,
    request=None,
    description: str = '',
    old_data=None,
    new_data=None,
    audit_event=None,
) -> BookingActionLog:
    """Create BookingActionLog with a linked AuditEvent."""
    from src.apps.core.request_meta import create_audit_event

    event = audit_event or create_audit_event(
        request, user=performed_by, action=action
    )
    return BookingActionLog.objects.create(
        booking=booking,
        action=action,
        performed_by=performed_by,
        description=description,
        old_data=old_data or {},
        new_data=new_data or {},
        audit_event=event,
    )
