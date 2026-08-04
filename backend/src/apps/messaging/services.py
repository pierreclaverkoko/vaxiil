from __future__ import annotations

import time

from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.db import transaction
from django.db.models import Q
from django.utils import timezone
from django.utils.translation import gettext as _
from rest_framework.exceptions import PermissionDenied, ValidationError

from src.apps.bookings.access import user_is_org_booking_staff
from src.apps.bookings.models import Booking
from src.apps.messaging.models import (
    Conversation,
    ConversationInvite,
    ConversationParticipant,
    Message,
    PeerInviteBlock,
)
from src.apps.messaging.notify import notify_message_invite, notify_new_message
from src.apps.notifications.models import Notification
from src.apps.organizations.models import Organization, OrganizationMembership
from src.apps.payments.services.refunds import booking_is_paid

_BOOKING_MESSAGING_TERMINAL = frozenset(
    {
        Booking.BookingStatus.COMPLETED,
        Booking.BookingStatus.CANCELLED,
        Booking.BookingStatus.NO_SHOW,
    }
)

User = get_user_model()

OPAQUE_INVITE_ACK = _(
    'If this person is on Vaxiil, an invitation will be sent.'
)
INVITE_RATE_LIMIT = 10
INVITE_RATE_WINDOW_SECONDS = 3600


def normalize_email(value: str) -> str:
    return (value or '').strip().lower()


def normalize_phone(value: str) -> str:
    return ''.join(ch for ch in (value or '') if ch.isdigit() or ch == '+')


def normalize_alias(value: str) -> str:
    return (value or '').strip()


def _invite_rate_key(user_id) -> str:
    return f'messaging:invite_rate:{user_id}'


def check_invite_rate_limit(user) -> None:
    key = _invite_rate_key(user.id)
    count = cache.get(key, 0)
    if count >= INVITE_RATE_LIMIT:
        raise ValidationError(
            {'detail': _('Too many invitations. Please try again later.')}
        )
    if count == 0:
        cache.set(key, 1, INVITE_RATE_WINDOW_SECONDS)
    else:
        cache.incr(key)


def resolve_invite_target(*, email=None, phone=None, trust_alias=None):
    """Return (kind, normalized, user_or_None). Never raises for missing user."""
    provided = [bool(email), bool(phone), bool(trust_alias)]
    if sum(provided) != 1:
        raise ValidationError(
            {'detail': _('Provide exactly one of email, phone, or trust_alias.')}
        )
    if email:
        norm = normalize_email(email)
        user = User.objects.filter(email__iexact=norm).first()
        return 'email', norm, user
    if phone:
        norm = normalize_phone(phone)
        user = User.objects.filter(phone=norm).first() if norm else None
        if user is None and norm:
            # Soft match digits-only stored phones.
            digits = ''.join(ch for ch in norm if ch.isdigit())
            user = (
                User.objects.filter(phone__icontains=digits).first()
                if digits
                else None
            )
        return 'phone', norm, user
    norm = normalize_alias(trust_alias)
    user = User.objects.filter(trust_alias__iexact=norm).first()
    return 'trust_alias', norm, user


def submit_invite(*, initiator, email=None, phone=None, trust_alias=None) -> dict:
    """Opaque invite submit — same response whether or not recipient exists."""
    check_invite_rate_limit(initiator)
    kind, norm, recipient = resolve_invite_target(
        email=email, phone=phone, trust_alias=trust_alias
    )
    # Rough constant timing pad.
    t0 = time.monotonic()
    if recipient and recipient.id != initiator.id:
        blocked = PeerInviteBlock.objects.filter(
            blocker=recipient, blocked_peer=initiator
        ).exists()
        if not blocked:
            existing = ConversationInvite.objects.filter(
                initiator=initiator,
                recipient=recipient,
                status=ConversationInvite.Status.PENDING,
            ).exists()
            if not existing:
                invite = ConversationInvite.objects.create(
                    initiator=initiator,
                    recipient=recipient,
                    target_kind=kind,
                    target_value_normalized=norm,
                )
                notify_message_invite(
                    recipient=recipient, initiator=initiator, invite=invite
                )
    elapsed = time.monotonic() - t0
    if elapsed < 0.05:
        time.sleep(0.05 - elapsed)
    return {'detail': str(OPAQUE_INVITE_ACK)}


def expire_invites_for_alias(old_alias: str) -> int:
    if not old_alias:
        return 0
    return ConversationInvite.objects.filter(
        target_kind='trust_alias',
        target_value_normalized__iexact=old_alias.strip(),
        status=ConversationInvite.Status.PENDING,
    ).update(status=ConversationInvite.Status.EXPIRED)


@transaction.atomic
def accept_invite(*, invite: ConversationInvite, user) -> Conversation:
    if invite.recipient_id != user.id:
        raise PermissionDenied(_('You cannot accept this invitation.'))
    if invite.status != ConversationInvite.Status.PENDING:
        raise ValidationError({'detail': _('This invitation is no longer pending.')})
    conversation = Conversation.objects.create(
        kind=Conversation.Kind.DIRECT,
        status=Conversation.Status.ACTIVE,
    )
    ConversationParticipant.objects.create(conversation=conversation, user=invite.initiator)
    ConversationParticipant.objects.create(conversation=conversation, user=user)
    invite.status = ConversationInvite.Status.ACCEPTED
    invite.conversation = conversation
    invite.save(update_fields=['status', 'conversation', 'updated_at'])
    return conversation


@transaction.atomic
def decline_invite(*, invite: ConversationInvite, user, also_block: bool = False) -> None:
    if invite.recipient_id != user.id:
        raise PermissionDenied(_('You cannot decline this invitation.'))
    if invite.status != ConversationInvite.Status.PENDING:
        raise ValidationError({'detail': _('This invitation is no longer pending.')})
    invite.status = ConversationInvite.Status.DECLINED
    invite.save(update_fields=['status', 'updated_at'])
    if also_block:
        PeerInviteBlock.objects.get_or_create(
            blocker=user, blocked_peer=invite.initiator
        )


def user_can_access_conversation(user, conversation: Conversation) -> bool:
    if ConversationParticipant.objects.filter(
        conversation=conversation, user=user
    ).exists():
        return True
    if conversation.kind == Conversation.Kind.PLATFORM_SUPPORT and getattr(
        user, 'is_staff', False
    ):
        return True
    if conversation.kind == Conversation.Kind.BOOKING and conversation.booking_id:
        booking = conversation.booking
        if booking.user_id == user.id:
            return True
        return user_is_org_booking_staff(user, booking.organization_id)
    if conversation.kind == Conversation.Kind.SUPPORT and conversation.organization_id:
        if ConversationParticipant.objects.filter(
            conversation=conversation, user=user
        ).exists():
            return True
        return user_is_org_booking_staff(user, conversation.organization_id)
    return False


def ensure_participant(user, conversation: Conversation, membership=None) -> ConversationParticipant:
    part, _ = ConversationParticipant.objects.get_or_create(
        conversation=conversation,
        user=user,
        defaults={'membership': membership},
    )
    return part


def conversation_is_send_blocked(conversation: Conversation) -> bool:
    return ConversationParticipant.objects.filter(
        conversation=conversation, blocked_at__isnull=False
    ).exists()


def booking_messaging_window_open(booking: Booking) -> bool:
    """True when booking chat may be created or receive new messages."""
    if not booking_is_paid(booking):
        return False
    if booking.status in _BOOKING_MESSAGING_TERMINAL:
        return False
    end = booking.latest_slot_end()
    if end is not None and timezone.now() >= end:
        return False
    return True


def close_booking_conversation(booking: Booking) -> None:
    """Mark the booking's conversation closed if it exists and is not already closed."""
    conversation = getattr(booking, 'conversation', None)
    if conversation is None:
        return
    if conversation.status == Conversation.Status.CLOSED:
        return
    conversation.status = Conversation.Status.CLOSED
    conversation.save(update_fields=['status', 'updated_at'])


def maybe_close_booking_conversation(booking: Booking) -> None:
    """Close booking chat when the messaging window has ended."""
    if booking_messaging_window_open(booking):
        return
    close_booking_conversation(booking)


def get_or_create_booking_conversation(*, user, booking_id) -> Conversation:
    try:
        booking = Booking.objects.select_related('organization', 'service').get(pk=booking_id)
    except Booking.DoesNotExist as exc:
        raise ValidationError({'booking_id': _('Booking not found.')}) from exc
    is_client = booking.user_id == user.id
    is_staff = user_is_org_booking_staff(user, booking.organization_id)
    if not (is_client or is_staff):
        raise PermissionDenied(_('You cannot open a thread for this booking.'))
    conversation = getattr(booking, 'conversation', None)
    if conversation is None:
        # Customers never start booking chat — only org staff may create the thread.
        if not is_staff:
            raise PermissionDenied(
                _('Only the business can start messaging for this booking.')
            )
        if not booking_messaging_window_open(booking):
            raise ValidationError(
                {
                    'detail': _(
                        'Messaging is available after payment and until the booking '
                        'ends or is completed.'
                    )
                }
            )
        conversation = Conversation.objects.create(
            kind=Conversation.Kind.BOOKING,
            status=Conversation.Status.ACTIVE,
            booking=booking,
            organization=booking.organization,
        )
        ConversationParticipant.objects.create(conversation=conversation, user=booking.user)
    else:
        maybe_close_booking_conversation(booking)
        conversation.refresh_from_db()
    membership = None
    if is_staff:
        membership = OrganizationMembership.objects.filter(
            user=user, organization_id=booking.organization_id
        ).first()
    ensure_participant(user, conversation, membership=membership)
    return conversation


def get_or_create_support_conversation(*, user, organization_id) -> Conversation:
    try:
        org = Organization.objects.get(pk=organization_id)
    except Organization.DoesNotExist as exc:
        raise ValidationError({'organization_id': _('Organization not found.')}) from exc
    existing = (
        Conversation.objects.filter(
            kind=Conversation.Kind.SUPPORT,
            organization=org,
            status=Conversation.Status.ACTIVE,
            participants__user=user,
        )
        .distinct()
        .first()
    )
    if existing:
        return existing
    conversation = Conversation.objects.create(
        kind=Conversation.Kind.SUPPORT,
        status=Conversation.Status.ACTIVE,
        organization=org,
    )
    ConversationParticipant.objects.create(conversation=conversation, user=user)
    return conversation


def get_or_create_platform_support_conversation(*, actor, user_id=None) -> Conversation:
    """Open platform CS chat. Users open for themselves; staff may pass user_id."""
    if user_id is not None:
        if not getattr(actor, 'is_staff', False):
            raise PermissionDenied(
                _('Only platform staff can open support for another user.')
            )
        try:
            client = User.objects.get(pk=user_id)
        except User.DoesNotExist as exc:
            raise ValidationError({'user_id': _('User not found.')}) from exc
    else:
        client = actor

    existing = (
        Conversation.objects.filter(
            kind=Conversation.Kind.PLATFORM_SUPPORT,
            status=Conversation.Status.ACTIVE,
            participants__user=client,
        )
        .distinct()
        .first()
    )
    if existing:
        ensure_participant(actor, existing)
        if client.id != actor.id:
            ensure_participant(client, existing)
        return existing

    conversation = Conversation.objects.create(
        kind=Conversation.Kind.PLATFORM_SUPPORT,
        status=Conversation.Status.ACTIVE,
    )
    ConversationParticipant.objects.create(conversation=conversation, user=client)
    if actor.id != client.id:
        ConversationParticipant.objects.create(conversation=conversation, user=actor)
    return conversation


def send_message(*, user, conversation: Conversation, body: str) -> Message:
    body = (body or '').strip()
    if not body:
        raise ValidationError({'body': _('Message cannot be empty.')})
    if not user_can_access_conversation(user, conversation):
        raise PermissionDenied(_('You cannot send to this conversation.'))
    # Close booking threads outside the send atomic so a denied send still persists close.
    if (
        conversation.kind == Conversation.Kind.BOOKING
        and conversation.booking_id
    ):
        maybe_close_booking_conversation(conversation.booking)
        conversation.refresh_from_db()
    if conversation.status not in (
        Conversation.Status.ACTIVE,
        Conversation.Status.BLOCKED,
    ):
        raise ValidationError({'detail': _('This conversation is not active.')})
    if conversation_is_send_blocked(conversation):
        raise ValidationError({'detail': _('This conversation is blocked.')})
    return _create_and_notify_message(user=user, conversation=conversation, body=body)


@transaction.atomic
def _create_and_notify_message(*, user, conversation: Conversation, body: str) -> Message:
    membership = None
    if conversation.organization_id and user_is_org_booking_staff(
        user, conversation.organization_id
    ):
        membership = OrganizationMembership.objects.filter(
            user=user, organization_id=conversation.organization_id
        ).first()
    ensure_participant(user, conversation, membership=membership)
    message = Message.objects.create(
        conversation=conversation,
        sender_user=user,
        sender_membership=membership,
        body=body,
    )
    conversation.last_message_at = message.created_at
    if conversation.status == Conversation.Status.BLOCKED:
        # Keep blocked status if still blocked; send already denied above.
        pass
    conversation.save(update_fields=['last_message_at', 'updated_at'])
    # Notify other participants.
    others = ConversationParticipant.objects.filter(
        conversation=conversation
    ).exclude(user=user)
    for part in others.select_related('user'):
        audience = Notification.Audience.PERSONAL
        if conversation.kind in (
            Conversation.Kind.BOOKING,
            Conversation.Kind.SUPPORT,
        ) and conversation.organization_id:
            if user_is_org_booking_staff(part.user, conversation.organization_id):
                audience = Notification.Audience.ORGANIZATION
        elif conversation.kind == Conversation.Kind.PLATFORM_SUPPORT:
            if getattr(part.user, 'is_staff', False):
                audience = Notification.Audience.STAFF
        notify_new_message(
            recipient=part.user,
            conversation=conversation,
            preview=body[:120],
            audience=audience,
        )
    # Also notify org staff for support/booking if client sent and staff not yet participants.
    if (
        conversation.kind in (Conversation.Kind.BOOKING, Conversation.Kind.SUPPORT)
        and conversation.organization_id
        and not membership
    ):
        staff_memberships = OrganizationMembership.objects.filter(
            organization_id=conversation.organization_id,
            role__in=[
                OrganizationMembership.OrganizationMemberRole.OWNER,
                OrganizationMembership.OrganizationMemberRole.ADMIN,
                OrganizationMembership.OrganizationMemberRole.MANAGER,
                OrganizationMembership.OrganizationMemberRole.STAFF,
            ],
        ).select_related('user')
        notified = {p.user_id for p in others}
        for m in staff_memberships:
            if m.user_id not in notified and m.user_id != user.id:
                notify_new_message(
                    recipient=m.user,
                    conversation=conversation,
                    preview=body[:120],
                    audience=Notification.Audience.ORGANIZATION,
                )
    # Platform support: notify all staff when the client messages.
    if (
        conversation.kind == Conversation.Kind.PLATFORM_SUPPORT
        and not getattr(user, 'is_staff', False)
    ):
        notified = {p.user_id for p in others}
        for staff_user in User.objects.filter(is_staff=True, is_active=True):
            if staff_user.id not in notified and staff_user.id != user.id:
                notify_new_message(
                    recipient=staff_user,
                    conversation=conversation,
                    preview=body[:120],
                    audience=Notification.Audience.STAFF,
                )
    return message


@transaction.atomic
def block_conversation(*, user, conversation: Conversation) -> ConversationParticipant:
    if not user_can_access_conversation(user, conversation):
        raise PermissionDenied(_('You cannot block this conversation.'))
    part = ensure_participant(user, conversation)
    part.blocked_at = timezone.now()
    part.save(update_fields=['blocked_at', 'updated_at'])
    conversation.status = Conversation.Status.BLOCKED
    conversation.save(update_fields=['status', 'updated_at'])
    return part


@transaction.atomic
def unblock_conversation(*, user, conversation: Conversation) -> ConversationParticipant:
    if not user_can_access_conversation(user, conversation):
        raise PermissionDenied(_('You cannot unblock this conversation.'))
    part = ensure_participant(user, conversation)
    part.blocked_at = None
    part.save(update_fields=['blocked_at', 'updated_at'])
    still_blocked = conversation_is_send_blocked(conversation)
    conversation.status = (
        Conversation.Status.BLOCKED if still_blocked else Conversation.Status.ACTIVE
    )
    conversation.save(update_fields=['status', 'updated_at'])
    return part


def mark_conversation_read(*, user, conversation: Conversation) -> ConversationParticipant:
    if not user_can_access_conversation(user, conversation):
        raise PermissionDenied(_('You cannot access this conversation.'))
    part = ensure_participant(user, conversation)
    part.last_read_at = timezone.now()
    part.save(update_fields=['last_read_at', 'updated_at'])
    return part


def conversations_for_user(user, *, organization_id=None, scope=None):
    """Conversations filtered by personal / organization / staff scope."""
    if organization_id:
        if not user_is_org_booking_staff(user, organization_id):
            raise PermissionDenied(_('Not a member of this organization.'))
        return Conversation.objects.filter(
            organization_id=organization_id,
            kind__in=[Conversation.Kind.BOOKING, Conversation.Kind.SUPPORT],
        ).distinct()

    scope = (scope or 'personal').strip().lower()
    if scope == 'staff':
        if not getattr(user, 'is_staff', False):
            raise PermissionDenied(_('Staff access required.'))
        return Conversation.objects.filter(
            kind=Conversation.Kind.PLATFORM_SUPPORT,
        ).distinct()

    staff_org_ids = list(
        OrganizationMembership.objects.filter(
            user=user,
            role__in=[
                OrganizationMembership.OrganizationMemberRole.OWNER,
                OrganizationMembership.OrganizationMemberRole.ADMIN,
                OrganizationMembership.OrganizationMemberRole.MANAGER,
                OrganizationMembership.OrganizationMemberRole.STAFF,
            ],
        ).values_list('organization_id', flat=True)
    )

    # Personal: direct; bookings as client; support as client (not org staff);
    # platform support as the customer (never as staff).
    q = Q(kind=Conversation.Kind.DIRECT, participants__user=user) | Q(
        kind=Conversation.Kind.BOOKING, booking__user=user
    )
    support_q = Q(kind=Conversation.Kind.SUPPORT, participants__user=user)
    if staff_org_ids:
        support_q &= ~Q(organization_id__in=staff_org_ids)
    q = q | support_q
    if not getattr(user, 'is_staff', False):
        q = q | Q(
            kind=Conversation.Kind.PLATFORM_SUPPORT, participants__user=user
        )
    return Conversation.objects.filter(q).distinct()
