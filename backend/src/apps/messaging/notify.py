from django.conf import settings
from django.utils.translation import gettext as _

from src.apps.messaging.models import Conversation
from src.apps.notifications.models import Notification
from src.apps.notifications.services import notify_user


def _site_url() -> str:
    return (getattr(settings, 'SITE_URL', None) or 'http://localhost:8000').rstrip('/')


def notify_message_invite(*, recipient, initiator, invite=None) -> None:
    alias = initiator.trust_alias or _('Someone')
    notify_user(
        user=recipient,
        kind=Notification.Kind.MESSAGE_INVITE,
        title=_('New conversation invitation'),
        body=_(
            '%(alias)s invited you to chat on Vaxiil. '
            'They cannot see whether you are on the platform until you accept.'
        )
        % {'alias': alias},
        message_invite=invite,
        audience=Notification.Audience.PERSONAL,
        send_email=True,
        cta_url=f'{_site_url()}/messages',
        cta_label=_('View invitations'),
    )


def notify_new_message(
    *,
    recipient,
    conversation,
    preview: str,
    audience: str | None = None,
) -> None:
    if audience is None:
        if conversation.kind == Conversation.Kind.PLATFORM_SUPPORT:
            if getattr(recipient, 'is_staff', False):
                audience = Notification.Audience.STAFF
            else:
                audience = Notification.Audience.PERSONAL
        elif conversation.kind in (
            Conversation.Kind.BOOKING,
            Conversation.Kind.SUPPORT,
        ) and conversation.organization_id:
            # Caller should pass audience for org staff vs client.
            audience = Notification.Audience.PERSONAL
        else:
            audience = Notification.Audience.PERSONAL

    organization = None
    if audience == Notification.Audience.ORGANIZATION:
        organization = getattr(conversation, 'organization', None)

    notify_user(
        user=recipient,
        kind=Notification.Kind.MESSAGE_RECEIVED,
        title=_('New message'),
        body=preview or _('You have a new message.'),
        booking=getattr(conversation, 'booking', None),
        conversation=conversation,
        organization=organization,
        audience=audience,
        send_email=False,
        cta_url=f'{_site_url()}/messages/{conversation.id}',
        cta_label=_('Open conversation'),
    )
