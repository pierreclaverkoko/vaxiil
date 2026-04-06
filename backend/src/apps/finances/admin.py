from django.contrib import admin

from src.apps.finances.models import Currency


@admin.register(Currency)
class CurrencyAdmin(admin.ModelAdmin):
    list_display = ('code', 'name', 'symbol', 'numeric_code', 'minor_units', 'is_active')
    list_filter = ('is_active',)
    search_fields = ('code', 'name')
