from django.contrib import admin

from src.apps.messaging.models import (
    Conversation,
    ConversationInvite,
    ConversationParticipant,
    Message,
    PeerInviteBlock,
)


@admin.register(Conversation)
class ConversationAdmin(admin.ModelAdmin):
    list_display = ['id', 'kind', 'status', 'organization', 'last_message_at', 'created_at']
    list_filter = ['kind', 'status']
    search_fields = ['id']


@admin.register(ConversationParticipant)
class ConversationParticipantAdmin(admin.ModelAdmin):
    list_display = ['id', 'conversation', 'user', 'blocked_at', 'last_read_at']
    search_fields = ['user__email', 'user__trust_alias']


@admin.register(Message)
class MessageAdmin(admin.ModelAdmin):
    list_display = ['id', 'conversation', 'sender_user', 'created_at']
    search_fields = ['body', 'sender_user__email']


@admin.register(ConversationInvite)
class ConversationInviteAdmin(admin.ModelAdmin):
    list_display = ['id', 'initiator', 'recipient', 'status', 'created_at']
    list_filter = ['status']


@admin.register(PeerInviteBlock)
class PeerInviteBlockAdmin(admin.ModelAdmin):
    list_display = ['id', 'blocker', 'blocked_peer', 'created_at']
