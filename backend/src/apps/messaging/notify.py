from django.conf import settings
from django.utils.translation import gettext as _

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
        send_email=True,
        cta_url=f'{_site_url()}/messages',
        cta_label=_('View invitations'),
    )


def notify_new_message(*, recipient, conversation, preview: str) -> None:
    notify_user(
        user=recipient,
        kind=Notification.Kind.MESSAGE_RECEIVED,
        title=_('New message'),
        body=preview or _('You have a new message.'),
        booking=getattr(conversation, 'booking', None),
        conversation=conversation,
        send_email=False,
        cta_url=f'{_site_url()}/messages/{conversation.id}',
        cta_label=_('Open conversation'),
    )
