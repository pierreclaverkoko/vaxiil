from django.conf import settings
from django.db import models
from django.utils.translation import gettext_lazy as _

from src.apps.core.models import SoftDeleteModel


class Conversation(SoftDeleteModel):
    class Kind(models.TextChoices):
        DIRECT = 'direct', _('Direct')
        BOOKING = 'booking', _('Booking')
        SUPPORT = 'support', _('Support')
        PLATFORM_SUPPORT = 'platform', _('Platform support')

    class Status(models.TextChoices):
        PENDING = 'pending', _('Pending')
        ACTIVE = 'active', _('Active')
        DECLINED = 'declined', _('Declined')
        CLOSED = 'closed', _('Closed')
        BLOCKED = 'blocked', _('Blocked')

    _KIND_CSS = {
        Kind.DIRECT: 'primary',
        Kind.BOOKING: 'info',
        Kind.SUPPORT: 'warning',
        Kind.PLATFORM_SUPPORT: 'danger',
    }
    _STATUS_CSS = {
        Status.PENDING: 'warning',
        Status.ACTIVE: 'success',
        Status.DECLINED: 'secondary',
        Status.CLOSED: 'default',
        Status.BLOCKED: 'danger',
    }

    kind = models.CharField(max_length=16, choices=Kind.choices, db_index=True)
    status = models.CharField(
        max_length=16,
        choices=Status.choices,
        default=Status.ACTIVE,
        db_index=True,
    )
    booking = models.OneToOneField(
        'bookings.Booking',
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='conversation',
    )
    organization = models.ForeignKey(
        'organizations.Organization',
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='conversations',
    )
    last_message_at = models.DateTimeField(null=True, blank=True, db_index=True)

    class Meta:
        db_table = 'messaging_conversations'
        ordering = ['-last_message_at', '-created_at']
        indexes = [
            models.Index(fields=['kind', 'status']),
            models.Index(fields=['organization', '-last_message_at']),
        ]

    def get_kind_css(self):
        return self._KIND_CSS.get(self.kind, 'default')

    def get_status_css(self):
        return self._STATUS_CSS.get(self.status, 'default')

    def __str__(self):
        return f'{self.kind}:{self.id}'


class ConversationParticipant(SoftDeleteModel):
    conversation = models.ForeignKey(
        Conversation,
        on_delete=models.CASCADE,
        related_name='participants',
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='conversation_participations',
    )
    membership = models.ForeignKey(
        'organizations.OrganizationMembership',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='conversation_participations',
    )
    blocked_at = models.DateTimeField(null=True, blank=True)
    last_read_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = 'messaging_conversation_participants'
        constraints = [
            models.UniqueConstraint(
                fields=['conversation', 'user'],
                condition=models.Q(deleted_at__isnull=True),
                name='unique_active_conversation_participant',
            ),
        ]
        indexes = [
            models.Index(fields=['user', '-created_at']),
        ]

    def __str__(self):
        return f'{self.user_id} in {self.conversation_id}'


class Message(SoftDeleteModel):
    conversation = models.ForeignKey(
        Conversation,
        on_delete=models.CASCADE,
        related_name='messages',
    )
    sender_user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='sent_messages',
    )
    sender_membership = models.ForeignKey(
        'organizations.OrganizationMembership',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='sent_messages',
    )
    body = models.TextField()

    class Meta:
        db_table = 'messaging_messages'
        ordering = ['created_at']
        indexes = [
            models.Index(fields=['conversation', 'created_at']),
        ]

    def __str__(self):
        return f'msg:{self.id}'


class ConversationInvite(SoftDeleteModel):
    class Status(models.TextChoices):
        PENDING = 'pending', _('Pending')
        ACCEPTED = 'accepted', _('Accepted')
        DECLINED = 'declined', _('Declined')
        EXPIRED = 'expired', _('Expired')

    _STATUS_CSS = {
        Status.PENDING: 'warning',
        Status.ACCEPTED: 'success',
        Status.DECLINED: 'secondary',
        Status.EXPIRED: 'default',
    }

    initiator = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='sent_conversation_invites',
    )
    recipient = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='received_conversation_invites',
    )
    # Normalized lookup used when invite was created (for alias invalidation).
    target_kind = models.CharField(max_length=16, blank=True, default='')
    target_value_normalized = models.CharField(max_length=255, blank=True, default='')
    status = models.CharField(
        max_length=16,
        choices=Status.choices,
        default=Status.PENDING,
        db_index=True,
    )
    conversation = models.ForeignKey(
        Conversation,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='invites',
    )

    class Meta:
        db_table = 'messaging_conversation_invites'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['recipient', 'status']),
            models.Index(fields=['initiator', 'status']),
            models.Index(fields=['target_kind', 'target_value_normalized', 'status']),
        ]

    def get_status_css(self):
        return self._STATUS_CSS.get(self.status, 'default')

    def __str__(self):
        return f'invite:{self.id}:{self.status}'


class PeerInviteBlock(SoftDeleteModel):
    """Suppress P2P invites from a peer until the blocker removes the block."""

    blocker = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='peer_invite_blocks',
    )
    blocked_peer = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='peer_invite_blocks_against',
    )

    class Meta:
        db_table = 'messaging_peer_invite_blocks'
        constraints = [
            models.UniqueConstraint(
                fields=['blocker', 'blocked_peer'],
                condition=models.Q(deleted_at__isnull=True),
                name='unique_active_peer_invite_block',
            ),
        ]

    def __str__(self):
        return f'{self.blocker_id} blocks invites from {self.blocked_peer_id}'
