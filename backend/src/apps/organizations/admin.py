from django.contrib import admin
from .models import (
    OrganizationTypeModel, Organization, OrganizationSettings, 
    VerificationStatus, OrganizationTypeSubCategory
)


@admin.register(Organization)
class OrganizationAdmin(admin.ModelAdmin):
    list_display = [
        'name', 'type', 'email', 'verification_status',
        'is_active', 'accepts_bookings', 'created_at'
    ]
    
    list_filter = [
        'type', 'verification_status', 'is_active',
        'accepts_bookings', 'created_at'
    ]
    
    search_fields = ['name', 'email', 'business_license_number']
    
    ordering = ['-created_at']
    
    fieldsets = (
        (None, {
            'fields': ('name', 'type', 'email')
        }),
        ('Contact Info', {
            'fields': ('phone', 'website')
        }),
        ('Location', {
            'fields': (
                'address', 'city', 'postal_code', 'country',
                'latitude', 'longitude'
            )
        }),
        ('KYB Information', {
            'fields': (
                'verification_status', 'business_license_number',
                'tax_id', 'business_license_document', 'id_document'
            )
        }),
        ('Verification Details', {
            'fields': ('verified_at', 'verified_by', 'rejection_reason')
        }),
        ('Business Settings', {
            'fields': (
                'is_active', 'accepts_bookings',
                'requires_prepayment'
            )
        }),
    )
    
    readonly_fields = [
        'verified_at', 'verified_by', 'created_at', 'updated_at'
    ]
    
    actions = ['approve_verification', 'reject_verification']
    
    def approve_verification(self, request, queryset):
        queryset.update(
            verification_status=VerificationStatus.VERIFIED,
            verified_by=request.user
        )
    approve_verification.short_description = 'Approve selected organizations'
    
    def reject_verification(self, request, queryset):
        queryset.update(verification_status=VerificationStatus.REJECTED)
    reject_verification.short_description = 'Reject selected organizations'


@admin.register(OrganizationSettings)
class OrganizationSettingsAdmin(admin.ModelAdmin):
    list_display = [
        'organization', 'minimum_booking_hours_notice',
        'maximum_booking_days_ahead', 'cancellation_hours_notice',
        'commission_rate', 'payout_delay_days'
    ]
    
    list_filter = [
        'minimum_booking_hours_notice',
        'maximum_booking_days_ahead',
        'cancellation_hours_notice'
    ]
    
    search_fields = ['organization__name']
    
    ordering = ['organization__name']


@admin.register(OrganizationTypeModel)
class OrganizationTypeModelAdmin(admin.ModelAdmin):
    list_display = ['display_name', 'name', 'is_active', 'created_at']
    list_filter = ['is_active', 'created_at']
    search_fields = ['name', 'display_name', 'description']
    ordering = ['display_name']
    
    fieldsets = (
        (None, {
            'fields': ('name', 'display_name', 'is_active')
        }),
        ('Details', {
            'fields': ('description', 'icon')
        }),
    )


@admin.register(OrganizationTypeSubCategory)
class OrganizationTypeSubCategoryAdmin(admin.ModelAdmin):
    list_display = [
        'organization_type', 'sub_category', 'is_default', 'created_at'
    ]
    list_filter = ['organization_type', 'is_default', 'created_at']
    search_fields = ['organization_type__display_name', 'sub_category__name']
    ordering = ['organization_type', 'sub_category']
    
    fieldsets = (
        (None, {
            'fields': ('organization_type', 'sub_category', 'is_default')
        }),
    )
