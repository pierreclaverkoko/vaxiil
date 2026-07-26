from django.conf import settings
from django.utils.translation import gettext as _

from src.apps.notifications.models import Notification
from src.apps.notifications.services import notify_user
from src.apps.organizations.models import OrganizationMembership


def _site_url() -> str:
    return (getattr(settings, 'SITE_URL', None) or 'http://localhost:8000').rstrip('/')


def notify_kyc_approved(*, user) -> None:
    notify_user(
        user=user,
        kind=Notification.Kind.KYC_APPROVED,
        title=_('Identity verified'),
        body=_(
            'Your identity verification was approved. '
            'You can now book services that require KYC.'
        ),
        send_email=True,
        cta_url=f'{_site_url()}/profile',
        cta_label=_('View profile'),
    )


def notify_kyc_rejected(*, user, reason: str = '') -> None:
    body = _('Your identity verification was rejected.')
    if reason:
        body = _('%(intro)s Reason: %(reason)s') % {
            'intro': body,
            'reason': reason,
        }
    notify_user(
        user=user,
        kind=Notification.Kind.KYC_REJECTED,
        title=_('Identity verification rejected'),
        body=body,
        send_email=True,
        cta_url=f'{_site_url()}/profile/verify',
        cta_label=_('Try again'),
    )


def notify_kyb_approved(*, organization) -> None:
    owners = OrganizationMembership.objects.filter(
        organization=organization,
        role__in=[
            OrganizationMembership.OrganizationMemberRole.OWNER,
            OrganizationMembership.OrganizationMemberRole.ADMIN,
        ],
    ).select_related('user')
    for membership in owners:
        notify_user(
            user=membership.user,
            kind=Notification.Kind.KYB_APPROVED,
            title=_('Business verified'),
            body=_('Verification for %(name)s was approved.')
            % {'name': organization.name},
            organization=organization,
            audience=Notification.Audience.ORGANIZATION,
            send_email=True,
            cta_url=f'{_site_url()}/business/{organization.id}',
            cta_label=_('Open company'),
        )


def notify_kyb_rejected(*, organization, reason: str = '') -> None:
    body = _('Verification for %(name)s was rejected.') % {'name': organization.name}
    if reason:
        body = _('%(intro)s Reason: %(reason)s') % {
            'intro': body,
            'reason': reason,
        }
    owners = OrganizationMembership.objects.filter(
        organization=organization,
        role__in=[
            OrganizationMembership.OrganizationMemberRole.OWNER,
            OrganizationMembership.OrganizationMemberRole.ADMIN,
        ],
    ).select_related('user')
    for membership in owners:
        notify_user(
            user=membership.user,
            kind=Notification.Kind.KYB_REJECTED,
            title=_('Business verification rejected'),
            body=body,
            organization=organization,
            audience=Notification.Audience.ORGANIZATION,
            send_email=True,
            cta_url=f'{_site_url()}/business/{organization.id}',
            cta_label=_('Review submission'),
        )
