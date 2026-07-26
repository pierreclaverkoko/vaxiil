from django.utils import timezone
from rest_framework import permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from src.apps.notifications.models import Notification
from src.apps.notifications.serializers import NotificationSerializer
from src.apps.notifications.services import notifications_for_user
from src.apps.users.permissions import IsEmailVerified


class NotificationViewSet(viewsets.ReadOnlyModelViewSet):
    permission_classes = [permissions.IsAuthenticated, IsEmailVerified]
    serializer_class = NotificationSerializer
    http_method_names = ['get', 'post', 'head', 'options']

    def get_queryset(self):
        org_id = self.request.query_params.get('organization_id')
        scope = self.request.query_params.get('scope')
        return notifications_for_user(
            self.request.user,
            scope=scope,
            organization_id=org_id,
        ).order_by('-created_at')

    @action(detail=True, methods=['post'], url_path='mark-read')
    def mark_read(self, request, pk=None):
        notification = self.get_object()
        if notification.read_at is None:
            notification.read_at = timezone.now()
            notification.save(update_fields=['read_at'])
        return Response(NotificationSerializer(notification).data, status=status.HTTP_200_OK)

    @action(detail=False, methods=['post'], url_path='mark-all-read')
    def mark_all_read(self, request):
        qs = self.get_queryset().filter(read_at__isnull=True)
        updated = qs.update(read_at=timezone.now())
        return Response({'updated': updated}, status=status.HTTP_200_OK)

    @action(detail=False, methods=['get'], url_path='unread-count')
    def unread_count(self, request):
        org_id = request.query_params.get('organization_id')
        scope = request.query_params.get('scope')
        count = notifications_for_user(
            request.user,
            scope=scope,
            organization_id=org_id,
        ).filter(read_at__isnull=True).count()
        return Response({'unread_count': count}, status=status.HTTP_200_OK)
