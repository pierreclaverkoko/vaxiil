from django.contrib import admin
from .models import (
    ServiceCategory, ServiceSubCategory,
    Service, ServiceVariant, ServiceVariantModel, ServiceMedia,
    ServiceFeature, ServiceFeatureType, ServiceFeatureMapping,
    OrganizationSubCategory
)


@admin.register(ServiceCategory)
class ServiceCategoryAdmin(admin.ModelAdmin):
    list_display = ['name', 'icon', 'is_active', 'sort_order', 'created_at']
    list_filter = ['is_active', 'created_at']
    search_fields = ['name', 'description']
    ordering = ['sort_order', 'name']
    prepopulated_fields = {}


class ServiceSubCategoryInline(admin.TabularInline):
    model = ServiceSubCategory
    extra = 1


@admin.register(ServiceSubCategory)
class ServiceSubCategoryAdmin(admin.ModelAdmin):
    list_display = [
        'name', 'category', 'is_active', 'sort_order', 'created_at'
    ]
    list_filter = ['category', 'is_active', 'created_at']
    search_fields = ['name', 'description']
    ordering = ['category', 'sort_order', 'name']


class ServiceVariantInline(admin.TabularInline):
    model = ServiceVariantModel
    extra = 1


class ServiceMediaInline(admin.TabularInline):
    model = ServiceMedia
    extra = 1


class ServiceFeatureMappingInline(admin.TabularInline):
    model = ServiceFeatureMapping
    extra = 1


@admin.register(Service)
class ServiceAdmin(admin.ModelAdmin):
    list_display = [
        'name', 'organization', 'sub_category', 'price_min',
        'price_max', 'is_active', 'featured', 'created_at'
    ]
    list_filter = [
        'organization', 'sub_category', 'is_active', 'featured',
        'requires_verification', 'created_at'
    ]
    search_fields = ['name', 'description', 'organization__name']
    ordering = ['-featured', 'name']
    inlines = [ServiceVariantInline, ServiceMediaInline, ServiceFeatureMappingInline]
    
    fieldsets = (
        (None, {
            'fields': (
                'name', 'organization', 'sub_category', 'description'
            )
        }),
        ('Pricing', {
            'fields': (
                'price_min', 'price_max', 'currency', 'requires_verification'
            )
        }),
        ('Availability Settings', {
            'fields': (
                'availability_type', 'max_bookings_per_day',
                'max_bookings_per_time_slot', 'booking_advance_days',
                'minimum_booking_hours', 'cancellation_hours'
            )
        }),
        ('Time Availability', {
            'fields': (
                'available_start_time', 'available_end_time'
            )
        }),
        ('Day Availability', {
            'fields': (
                'available_days',
            )
        }),
        ('Seasonal Availability', {
            'fields': (
                'seasonal_start_date', 'seasonal_end_date',
                'availability_notes'
            )
        }),
        ('Settings', {
            'fields': (
                'is_active', 'featured'
            )
        }),
    )


@admin.register(ServiceVariantModel)
class ServiceVariantModelAdmin(admin.ModelAdmin):
    list_display = [
        'name', 'service', 'duration_minutes', 'duration_type',
        'price', 'is_popular', 'is_active'
    ]
    list_filter = [
        'service', 'duration_type', 'is_popular', 'is_active'
    ]
    search_fields = ['name', 'service__name']
    ordering = ['service', 'is_popular', 'duration_minutes']


@admin.register(ServiceMedia)
class ServiceMediaAdmin(admin.ModelAdmin):
    list_display = [
        'service', 'media_type', 'title', 'is_primary',
        'sort_order', 'created_at'
    ]
    list_filter = ['media_type', 'is_primary', 'created_at']
    search_fields = ['service__name', 'title', 'description']
    ordering = ['service', 'sort_order']


class ServiceFeatureMappingInline(admin.TabularInline):
    model = ServiceFeatureMapping
    extra = 1


@admin.register(ServiceFeature)
class ServiceFeatureAdmin(admin.ModelAdmin):
    list_display = [
        'name', 'feature_type', 'icon', 'created_at'
    ]
    list_filter = ['feature_type', 'created_at']
    search_fields = ['name', 'description']
    ordering = ['feature_type', 'name']
    inlines = [ServiceFeatureMappingInline]


@admin.register(OrganizationSubCategory)
class OrganizationSubCategoryAdmin(admin.ModelAdmin):
    list_display = [
        'organization', 'sub_category', 'is_active', 
        'created_at', 'created_by'
    ]
    list_filter = [
        'organization', 'sub_category', 'is_active', 'created_at'
    ]
    search_fields = [
        'organization__name', 'sub_category__name', 'availability_notes'
    ]
    ordering = ['organization', 'sub_category']
    
    fieldsets = (
        (None, {
            'fields': (
                'organization', 'sub_category', 'is_active', 'availability_notes'
            )
        }),
        ('Metadata', {
            'fields': ('created_by',),
            'readonly_fields': ('created_at', 'updated_at')
        }),
    )
    
    readonly_fields = ['created_at', 'updated_at']
