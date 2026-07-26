from django.contrib.auth import get_user_model
from django.utils.translation import gettext as _
from django_drf_dynamics.serializers.fields import ChoiceEnumField
from rest_framework import serializers

from src.apps.messaging.models import Conversation, ConversationInvite, Message

User = get_user_model()


class SenderSerializer(serializers.Serializer):
    kind = serializers.ChoiceField(choices=['user', 'org_member', 'support_agent'])
    trust_alias = serializers.CharField(allow_null=True)
    membership_id = serializers.UUIDField(allow_null=True, required=False)
    # Org-internal / platform-staff richer identity.
    display_name = serializers.CharField(allow_null=True, required=False)


def build_sender(
    message: Message,
    *,
    viewer,
    include_org_identity: bool = False,
    include_platform_identity: bool = False,
) -> dict:
    alias = getattr(message.sender_user, 'trust_alias', None) or ''
    sender_is_staff = bool(getattr(message.sender_user, 'is_staff', False))
    is_platform = (
        message.conversation_id
        and message.conversation.kind == Conversation.Kind.PLATFORM_SUPPORT
    )
    if is_platform and sender_is_staff:
        data = {
            'kind': 'support_agent',
            'trust_alias': None,
            'membership_id': None,
        }
        if include_platform_identity:
            user = message.sender_user
            name = (user.get_full_name() or '').strip() or user.email
            data['display_name'] = name
        return data
    kind = 'org_member' if message.sender_membership_id else 'user'
    data = {
        'kind': kind,
        'trust_alias': alias or None,
        'membership_id': message.sender_membership_id,
    }
    if include_org_identity and message.sender_membership_id:
        user = message.sender_user
        name = (user.get_full_name() or '').strip() or user.email
        data['display_name'] = name
    return data


class MessageSerializer(serializers.ModelSerializer):
    sender = serializers.SerializerMethodField()
    is_mine = serializers.SerializerMethodField()

    class Meta:
        model = Message
        fields = ['id', 'body', 'created_at', 'sender', 'is_mine']
        read_only_fields = fields

    def get_sender(self, obj):
        request = self.context.get('request')
        viewer = getattr(request, 'user', None)
        include = bool(self.context.get('include_org_identity'))
        include_platform = bool(self.context.get('include_platform_identity'))
        return build_sender(
            obj,
            viewer=viewer,
            include_org_identity=include,
            include_platform_identity=include_platform,
        )

    def get_is_mine(self, obj):
        request = self.context.get('request')
        viewer = getattr(request, 'user', None)
        return bool(viewer and obj.sender_user_id == getattr(viewer, 'id', None))


class ConversationListSerializer(serializers.ModelSerializer):
    kind = ChoiceEnumField()
    status = ChoiceEnumField()
    title = serializers.SerializerMethodField()
    peer_trust_alias = serializers.SerializerMethodField()
    peer_age = serializers.SerializerMethodField()
    peer_sex = serializers.SerializerMethodField()
    last_message_preview = serializers.SerializerMethodField()
    unread = serializers.SerializerMethodField()
    is_blocked = serializers.SerializerMethodField()
    booking_id = serializers.UUIDField(read_only=True, allow_null=True)
    organization_id = serializers.UUIDField(read_only=True, allow_null=True)
    organization_name = serializers.SerializerMethodField()

    class Meta:
        model = Conversation
        fields = [
            'id',
            'kind',
            'status',
            'title',
            'peer_trust_alias',
            'peer_age',
            'peer_sex',
            'last_message_at',
            'last_message_preview',
            'unread',
            'is_blocked',
            'booking_id',
            'organization_id',
            'organization_name',
            'created_at',
        ]

    def _viewer(self):
        request = self.context.get('request')
        return getattr(request, 'user', None)

    def _peer_user(self, obj):
        viewer = self._viewer()
        if not viewer:
            return None
        peer = (
            obj.participants.exclude(user=viewer)
            .select_related('user')
            .first()
        )
        if peer:
            return peer.user
        if obj.kind == Conversation.Kind.BOOKING and obj.booking_id:
            if obj.booking.user_id != viewer.id:
                return obj.booking.user
        return None

    def get_title(self, obj):
        if obj.kind == Conversation.Kind.PLATFORM_SUPPORT:
            return _('Vaxiil Support')
        if obj.kind == Conversation.Kind.BOOKING and obj.booking_id:
            booking = obj.booking
            service_name = getattr(getattr(booking, 'service', None), 'name', None)
            org_name = getattr(getattr(booking, 'organization', None), 'name', None)
            if service_name and org_name:
                return _('%(service)s with %(org)s') % {
                    'service': service_name,
                    'org': org_name,
                }
            return service_name or org_name or _('Booking conversation')
        if obj.kind == Conversation.Kind.SUPPORT and obj.organization_id:
            return _('Support — %(org)s') % {
                'org': getattr(obj.organization, 'name', '') or _('Organization')
            }
        return self.get_peer_trust_alias(obj) or _('Conversation')

    def get_peer_trust_alias(self, obj):
        if obj.kind == Conversation.Kind.PLATFORM_SUPPORT:
            viewer = self._viewer()
            if viewer and getattr(viewer, 'is_staff', False):
                peer = self._peer_user(obj)
                return peer.trust_alias if peer else None
            return _('Vaxiil Support')
        peer = self._peer_user(obj)
        return peer.trust_alias if peer else None

    def get_peer_age(self, obj):
        peer = self._peer_user(obj)
        if not peer:
            return None
        return peer.age

    def get_peer_sex(self, obj):
        peer = self._peer_user(obj)
        if not peer or not peer.sex:
            return None
        return {
            'value': peer.sex,
            'title': peer.get_sex_display(),
            'css': peer.get_sex_css(),
        }

    def get_last_message_preview(self, obj):
        msg = obj.messages.order_by('-created_at').first()
        return msg.body[:160] if msg else ''

    def get_unread(self, obj):
        viewer = self._viewer()
        if not viewer:
            return False
        part = obj.participants.filter(user=viewer).first()
        last_read = part.last_read_at if part else None
        qs = obj.messages.exclude(sender_user=viewer)
        if last_read:
            qs = qs.filter(created_at__gt=last_read)
        return qs.exists()

    def get_is_blocked(self, obj):
        return obj.participants.filter(blocked_at__isnull=False).exists()

    def get_organization_name(self, obj):
        if obj.organization_id:
            return getattr(obj.organization, 'name', None)
        return None


class ConversationDetailSerializer(ConversationListSerializer):
    pass


class InviteSerializer(serializers.ModelSerializer):
    status = ChoiceEnumField()
    initiator_trust_alias = serializers.CharField(
        source='initiator.trust_alias', read_only=True, allow_null=True
    )
    initiator_age = serializers.SerializerMethodField()
    initiator_sex = serializers.SerializerMethodField()

    class Meta:
        model = ConversationInvite
        fields = [
            'id',
            'status',
            'initiator_trust_alias',
            'initiator_age',
            'initiator_sex',
            'created_at',
            'conversation',
        ]
        read_only_fields = fields

    def get_initiator_age(self, obj):
        return obj.initiator.age if obj.initiator_id else None

    def get_initiator_sex(self, obj):
        user = obj.initiator
        if not user or not user.sex:
            return None
        return {
            'value': user.sex,
            'title': user.get_sex_display(),
            'css': user.get_sex_css(),
        }


class InviteCreateSerializer(serializers.Serializer):
    email = serializers.EmailField(required=False, allow_blank=True)
    phone = serializers.CharField(required=False, allow_blank=True, max_length=32)
    trust_alias = serializers.CharField(required=False, allow_blank=True, max_length=100)

    def validate(self, attrs):
        email = (attrs.get('email') or '').strip() or None
        phone = (attrs.get('phone') or '').strip() or None
        trust_alias = (attrs.get('trust_alias') or '').strip() or None
        attrs['email'] = email
        attrs['phone'] = phone
        attrs['trust_alias'] = trust_alias
        return attrs


class SendMessageSerializer(serializers.Serializer):
    body = serializers.CharField(max_length=4000)


class BookingThreadSerializer(serializers.Serializer):
    booking_id = serializers.UUIDField()


class SupportThreadSerializer(serializers.Serializer):
    organization_id = serializers.UUIDField()


class PlatformSupportThreadSerializer(serializers.Serializer):
    user_id = serializers.UUIDField(required=False)
