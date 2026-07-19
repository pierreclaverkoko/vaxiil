from django.contrib import admin

from src.apps.payments.models import (
    PaymentProvider,
    PaymentTransaction,
    RefundWallet,
    RefundWalletLedger,
)


@admin.register(PaymentProvider)
class PaymentProviderAdmin(admin.ModelAdmin):
    list_display = ('code', 'provider_type', 'display_name', 'is_active', 'created_at')
    list_filter = ('provider_type', 'is_active')
    search_fields = ('code', 'display_name')
    filter_horizontal = ('supported_countries', 'supported_currencies')


@admin.register(PaymentTransaction)
class PaymentTransactionAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'booking',
        'kind',
        'status',
        'amount',
        'currency',
        'payment_provider',
        'created_at',
    )
    list_filter = ('kind', 'status', 'payment_provider')
    raw_id_fields = ('booking', 'payment_provider', 'user', 'initiated_by', 'currency')
    readonly_fields = ('created_at', 'updated_at')


@admin.register(RefundWallet)
class RefundWalletAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'currency', 'balance', 'updated_at')
    list_filter = ('currency',)
    raw_id_fields = ('user', 'currency')
    readonly_fields = ('created_at', 'updated_at')


@admin.register(RefundWalletLedger)
class RefundWalletLedgerAdmin(admin.ModelAdmin):
    list_display = ('id', 'wallet', 'kind', 'amount', 'balance_after', 'booking', 'created_at')
    list_filter = ('kind',)
    raw_id_fields = ('wallet', 'booking')
    readonly_fields = ('created_at',)
