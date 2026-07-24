from rest_framework import serializers

from src.apps.notifications.models import Notification


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = [
            'id',
            'kind',
            'title',
            'body',
            'booking',
            'read_at',
            'email_sent_at',
            'created_at',
        ]
        read_only_fields = fields
