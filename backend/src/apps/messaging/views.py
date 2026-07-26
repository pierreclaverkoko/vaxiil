from django.utils.translation import gettext as _
from rest_framework import permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import NotFound, PermissionDenied
from rest_framework.response import Response

from src.apps.bookings.access import user_is_org_booking_staff
from src.apps.messaging.models import Conversation, ConversationInvite, Message
from src.apps.messaging.serializers import (
    BookingThreadSerializer,
    ConversationDetailSerializer,
    ConversationListSerializer,
    InviteCreateSerializer,
    InviteSerializer,
    MessageSerializer,
    PlatformSupportThreadSerializer,
    SendMessageSerializer,
    SupportThreadSerializer,
)
from src.apps.messaging.services import (
    accept_invite,
    block_conversation,
    conversations_for_user,
    decline_invite,
    get_or_create_booking_conversation,
    get_or_create_platform_support_conversation,
    get_or_create_support_conversation,
    mark_conversation_read,
    send_message,
    submit_invite,
    unblock_conversation,
    user_can_access_conversation,
)
from src.apps.users.permissions import IsEmailVerified


class InviteViewSet(viewsets.GenericViewSet):
    permission_classes = [permissions.IsAuthenticated, IsEmailVerified]
    serializer_class = InviteSerializer

    def get_queryset(self):
        return ConversationInvite.objects.filter(
            recipient=self.request.user,
            status=ConversationInvite.Status.PENDING,
        ).select_related('initiator')

    def create(self, request):
        ser = InviteCreateSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        result = submit_invite(initiator=request.user, **ser.validated_data)
        return Response(result, status=status.HTTP_200_OK)

    @action(detail=False, methods=['get'], url_path='incoming')
    def incoming(self, request):
        qs = self.get_queryset()
        return Response(InviteSerializer(qs, many=True).data)

    @action(detail=True, methods=['post'], url_path='accept')
    def accept(self, request, pk=None):
        invite = ConversationInvite.objects.filter(pk=pk).first()
        if not invite:
            raise NotFound()
        conversation = accept_invite(invite=invite, user=request.user)
        data = ConversationDetailSerializer(
            conversation, context={'request': request}
        ).data
        return Response(data, status=status.HTTP_200_OK)

    @action(detail=True, methods=['post'], url_path='decline')
    def decline(self, request, pk=None):
        invite = ConversationInvite.objects.filter(pk=pk).first()
        if not invite:
            raise NotFound()
        also_block = bool(request.data.get('block'))
        decline_invite(invite=invite, user=request.user, also_block=also_block)
        return Response({'detail': _('Invitation declined.')}, status=status.HTTP_200_OK)


class ConversationViewSet(viewsets.ReadOnlyModelViewSet):
    permission_classes = [permissions.IsAuthenticated, IsEmailVerified]
    http_method_names = ['get', 'post', 'head', 'options']

    def get_serializer_class(self):
        if self.action == 'retrieve':
            return ConversationDetailSerializer
        return ConversationListSerializer

    def get_queryset(self):
        org_id = self.request.query_params.get('organization_id')
        qs = conversations_for_user(self.request.user, organization_id=org_id)
        return qs.select_related(
            'booking',
            'booking__service',
            'booking__organization',
            'booking__user',
            'organization',
        ).prefetch_related('participants__user', 'messages')

    def retrieve(self, request, *args, **kwargs):
        conversation = self.get_object()
        if not user_can_access_conversation(request.user, conversation):
            raise PermissionDenied()
        serializer = self.get_serializer(conversation)
        return Response(serializer.data)

    @action(detail=False, methods=['post'], url_path='booking')
    def booking_thread(self, request):
        ser = BookingThreadSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        conversation = get_or_create_booking_conversation(
            user=request.user, booking_id=ser.validated_data['booking_id']
        )
        return Response(
            ConversationDetailSerializer(
                conversation, context={'request': request}
            ).data,
            status=status.HTTP_200_OK,
        )

    @action(detail=False, methods=['post'], url_path='support')
    def support_thread(self, request):
        ser = SupportThreadSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        conversation = get_or_create_support_conversation(
            user=request.user,
            organization_id=ser.validated_data['organization_id'],
        )
        return Response(
            ConversationDetailSerializer(
                conversation, context={'request': request}
            ).data,
            status=status.HTTP_200_OK,
        )

    @action(detail=False, methods=['post'], url_path='platform-support')
    def platform_support_thread(self, request):
        ser = PlatformSupportThreadSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        conversation = get_or_create_platform_support_conversation(
            actor=request.user,
            user_id=ser.validated_data.get('user_id'),
        )
        return Response(
            ConversationDetailSerializer(
                conversation, context={'request': request}
            ).data,
            status=status.HTTP_200_OK,
        )

    @action(detail=True, methods=['get', 'post'], url_path='messages')
    def messages(self, request, pk=None):
        conversation = self.get_object()
        if not user_can_access_conversation(request.user, conversation):
            raise PermissionDenied()
        include_org = bool(
            conversation.organization_id
            and user_is_org_booking_staff(request.user, conversation.organization_id)
        )
        include_platform = bool(
            conversation.kind == Conversation.Kind.PLATFORM_SUPPORT
            and getattr(request.user, 'is_staff', False)
        )
        if request.method == 'GET':
            qs = Message.objects.filter(conversation=conversation).select_related(
                'sender_user', 'sender_membership', 'conversation'
            )
            since = request.query_params.get('since')
            if since:
                qs = qs.filter(created_at__gt=since)
            serializer = MessageSerializer(
                qs.order_by('created_at')[:200],
                many=True,
                context={
                    'request': request,
                    'include_org_identity': include_org,
                    'include_platform_identity': include_platform,
                },
            )
            return Response({'results': serializer.data})
        ser = SendMessageSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        message = send_message(
            user=request.user,
            conversation=conversation,
            body=ser.validated_data['body'],
        )
        return Response(
            MessageSerializer(
                message,
                context={
                    'request': request,
                    'include_org_identity': include_org,
                    'include_platform_identity': include_platform,
                },
            ).data,
            status=status.HTTP_201_CREATED,
        )

    @action(detail=True, methods=['post'], url_path='block')
    def block(self, request, pk=None):
        conversation = self.get_object()
        block_conversation(user=request.user, conversation=conversation)
        conversation.refresh_from_db()
        return Response(
            ConversationDetailSerializer(
                conversation, context={'request': request}
            ).data
        )

    @action(detail=True, methods=['post'], url_path='unblock')
    def unblock(self, request, pk=None):
        conversation = self.get_object()
        unblock_conversation(user=request.user, conversation=conversation)
        conversation.refresh_from_db()
        return Response(
            ConversationDetailSerializer(
                conversation, context={'request': request}
            ).data
        )

    @action(detail=True, methods=['post'], url_path='read')
    def read(self, request, pk=None):
        conversation = self.get_object()
        mark_conversation_read(user=request.user, conversation=conversation)
        return Response({'detail': _('Marked as read.')})
