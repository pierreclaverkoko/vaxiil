from django.contrib import admin

from src.apps.finances.models import (
    CategoryPlatformFee,
    Currency,
    CurrencyFxRate,
    OrganizationRevenueWallet,
    PlatformFeeEntry,
    PlatformSettings,
    SettlementAccount,
    SettlementRequest,
    SettlementSettings,
    UserPlatformCharge,
)


@admin.register(Currency)
class CurrencyAdmin(admin.ModelAdmin):
    list_display = ('code', 'name', 'symbol', 'numeric_code', 'minor_units', 'is_active')
    list_filter = ('is_active',)
    search_fields = ('code', 'name')


@admin.register(CurrencyFxRate)
class CurrencyFxRateAdmin(admin.ModelAdmin):
    list_display = (
        'from_currency',
        'to_currency',
        'rate',
        'effective_at',
        'created_at',
    )
    list_filter = ('from_currency', 'to_currency')


@admin.register(PlatformSettings)
class PlatformSettingsAdmin(admin.ModelAdmin):
    list_display = (
        'platform_fee_rate',
        'user_inscription_fee_usd',
        'business_annual_fee_usd',
        'settlement_minimum_usd',
        'updated_at',
    )


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


@admin.register(UserPlatformCharge)
class UserPlatformChargeAdmin(admin.ModelAdmin):
    list_display = ('user', 'kind', 'amount', 'currency', 'created_at')
    list_filter = ('kind',)


@admin.register(OrganizationRevenueWallet)
class OrganizationRevenueWalletAdmin(admin.ModelAdmin):
    list_display = ('organization', 'currency', 'balance', 'updated_at')


@admin.register(SettlementAccount)
class SettlementAccountAdmin(admin.ModelAdmin):
    list_display = (
        'organization',
        'method',
        'account_identifier',
        'is_default',
        'created_at',
    )
    list_filter = ('is_default', 'method__method_type')
    raw_id_fields = ('organization', 'method')
    search_fields = ('account_identifier', 'account_name', 'label')


@admin.register(SettlementSettings)
class SettlementSettingsAdmin(admin.ModelAdmin):
    list_display = ('organization', 'periodicity', 'minimum_amount', 'currency')


@admin.register(SettlementRequest)
class SettlementRequestAdmin(admin.ModelAdmin):
    list_display = (
        'organization',
        'amount',
        'currency',
        'status',
        'method_code',
        'created_at',
        'processed_at',
    )
    list_filter = ('status', 'method_code')
    readonly_fields = ('confirmation_image',)
