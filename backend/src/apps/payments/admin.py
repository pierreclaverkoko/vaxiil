from django.contrib import admin

from src.apps.payments.catalog import PaymentConnector, PaymentMethod
from src.apps.payments.models import (
    PaymentProvider,
    PaymentTransaction,
    RefundWallet,
    RefundWalletLedger,
)


class PaymentMethodInline(admin.TabularInline):
    model = PaymentMethod
    extra = 0
    fields = (
        'code',
        'name',
        'method_type',
        'country',
        'currency',
        'is_active',
        'supported_operations',
    )
    show_change_link = True


@admin.register(PaymentConnector)
class PaymentConnectorAdmin(admin.ModelAdmin):
    list_display = (
        'code',
        'name',
        'connector_type',
        'adapter_key',
        'is_active',
        'created_at',
    )
    list_filter = ('connector_type', 'is_active')
    search_fields = ('code', 'name', 'adapter_key')
    inlines = [PaymentMethodInline]


@admin.register(PaymentMethod)
class PaymentMethodAdmin(admin.ModelAdmin):
    list_display = (
        'code',
        'name',
        'connector',
        'method_type',
        'country',
        'currency',
        'is_active',
        'created_at',
    )
    list_filter = (
        'method_type',
        'connector',
        'is_active',
        'country',
    )
    search_fields = ('code', 'name', 'connector__code')
    raw_id_fields = ('connector', 'country', 'currency')
    readonly_fields = ('created_at', 'updated_at', 'deleted_at')


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
