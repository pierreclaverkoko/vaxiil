from django.contrib import admin

from src.apps.notifications.models import Notification


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'kind', 'title', 'read_at', 'email_sent_at', 'created_at')
    list_filter = ('kind',)
    search_fields = ('title', 'body', 'user__email')
    raw_id_fields = ('user', 'booking')
