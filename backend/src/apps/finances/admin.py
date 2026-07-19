from django.contrib import admin

from src.apps.finances.models import (
    CategoryPlatformFee,
    Currency,
    PlatformFeeEntry,
    PlatformSettings,
)


@admin.register(Currency)
class CurrencyAdmin(admin.ModelAdmin):
    list_display = ('code', 'name', 'symbol', 'numeric_code', 'minor_units', 'is_active')
    list_filter = ('is_active',)
    search_fields = ('code', 'name')


@admin.register(PlatformSettings)
class PlatformSettingsAdmin(admin.ModelAdmin):
    list_display = ('platform_fee_rate', 'updated_at')


@admin.register(CategoryPlatformFee)
class CategoryPlatformFeeAdmin(admin.ModelAdmin):
    list_display = ('category', 'rate', 'created_at', 'deleted_at')
    list_filter = ('deleted_at',)
    search_fields = ('category__name',)


@admin.register(PlatformFeeEntry)
class PlatformFeeEntryAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'organization',
        'booking',
        'amount',
        'rate',
        'payer',
        'source',
        'status',
        'created_at',
    )
    list_filter = ('status', 'payer', 'source')
    search_fields = ('organization__name', 'booking__id')
    readonly_fields = (
        'id',
        'booking',
        'organization',
        'category',
        'currency',
        'amount',
        'rate',
        'payer',
        'source',
        'status',
        'payment_transaction',
        'created_at',
    )
