from django.contrib import admin

from src.apps.bookings.models import (
    AvailabilityException,
    Booking,
    BookingRescheduleProposal,
    BookingTimeSlot,
    BusinessHours,
)


@admin.register(BusinessHours)
class BusinessHoursAdmin(admin.ModelAdmin):
    list_display = ('organization', 'day_of_week', 'open_time', 'close_time', 'is_closed')
    list_filter = ('day_of_week', 'is_closed')
    search_fields = ('organization__name',)


@admin.register(AvailabilityException)
class AvailabilityExceptionAdmin(admin.ModelAdmin):
    list_display = ('organization', 'date', 'reason', 'exception_type', 'is_closed')
    list_filter = ('exception_type', 'is_closed')
    search_fields = ('organization__name', 'reason')


class BookingTimeSlotInline(admin.TabularInline):
    model = BookingTimeSlot
    extra = 0


@admin.register(Booking)
class BookingAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'service', 'organization', 'status', 'total_price', 'created_at')
    list_filter = ('status',)
    search_fields = ('id', 'user__email', 'service__name', 'organization__name')
    inlines = [BookingTimeSlotInline]


@admin.register(BookingRescheduleProposal)
class BookingRescheduleProposalAdmin(admin.ModelAdmin):
    list_display = ('id', 'booking', 'proposed_by', 'status', 'created_at')
    list_filter = ('status', 'proposed_by')
