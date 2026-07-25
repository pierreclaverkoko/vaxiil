from __future__ import annotations

from django.db import transaction
from django.utils import timezone
from django.utils.translation import gettext as _
from rest_framework.exceptions import ValidationError

from src.apps.users.legal_models import LegalDocumentVersion, UserLegalAcceptance


def current_documents() -> dict[str, LegalDocumentVersion | None]:
    terms = (
        LegalDocumentVersion.objects.filter(
            document_type=LegalDocumentVersion.DocumentType.TERMS,
            is_current=True,
        )
        .order_by('-effective_at')
        .first()
    )
    privacy = (
        LegalDocumentVersion.objects.filter(
            document_type=LegalDocumentVersion.DocumentType.PRIVACY,
            is_current=True,
        )
        .order_by('-effective_at')
        .first()
    )
    return {'terms': terms, 'privacy': privacy}


def body_for_locale(doc: LegalDocumentVersion, lang: str) -> str:
    code = (lang or 'en').lower()[:2]
    if code == 'fr':
        return doc.body_fr
    return doc.body_en


def summary_for_locale(doc: LegalDocumentVersion, lang: str) -> str:
    code = (lang or 'en').lower()[:2]
    if code == 'fr':
        return doc.summary_fr or doc.summary_en
    return doc.summary_en or doc.summary_fr


def user_has_accepted(user, document: LegalDocumentVersion) -> bool:
    if user is None or not getattr(user, 'is_authenticated', False):
        return False
    return UserLegalAcceptance.objects.filter(user=user, document=document).exists()


def needs_legal_acceptance(user) -> bool:
    docs = current_documents()
    for doc in (docs['terms'], docs['privacy']):
        if doc is None:
            continue
        if not user_has_accepted(user, doc):
            return True
    return False


def legal_status_for_user(user) -> dict:
    docs = current_documents()
    terms = docs['terms']
    privacy = docs['privacy']
    accepted_terms = user_has_accepted(user, terms) if terms else True
    accepted_privacy = user_has_accepted(user, privacy) if privacy else True
    return {
        'terms_version': terms.version if terms else None,
        'terms_document_id': str(terms.id) if terms else None,
        'privacy_version': privacy.version if privacy else None,
        'privacy_document_id': str(privacy.id) if privacy else None,
        'accepted_terms': accepted_terms,
        'accepted_privacy': accepted_privacy,
        'needs_acceptance': not (accepted_terms and accepted_privacy),
    }


@transaction.atomic
def record_acceptance(
    *,
    user,
    terms_document: LegalDocumentVersion,
    privacy_document: LegalDocumentVersion,
    source: str,
    request=None,
) -> None:
    from src.apps.core.request_meta import LEGAL_ACCEPT, create_audit_event

    for doc in (terms_document, privacy_document):
        existing = UserLegalAcceptance.objects.filter(user=user, document=doc).first()
        if existing is not None:
            continue
        event = create_audit_event(request, user=user, action=LEGAL_ACCEPT)
        UserLegalAcceptance.objects.create(
            user=user,
            document=doc,
            source=source,
            audit_event=event,
        )


def require_current_acceptance_versions(
    *,
    accepted_terms_version: str | None,
    accepted_privacy_version: str | None,
) -> tuple[LegalDocumentVersion, LegalDocumentVersion]:
    docs = current_documents()
    terms = docs['terms']
    privacy = docs['privacy']
    if terms is None or privacy is None:
        raise ValidationError(
            {'legal': _('Legal documents are not configured on the server.')}
        )
    if accepted_terms_version != terms.version:
        raise ValidationError(
            {
                'accepted_terms_version': _(
                    'You must accept the current Terms of Service.'
                )
            }
        )
    if accepted_privacy_version != privacy.version:
        raise ValidationError(
            {
                'accepted_privacy_version': _(
                    'You must accept the current Privacy Policy.'
                )
            }
        )
    return terms, privacy


def publish_version(
    *,
    document_type: str,
    version: str,
    body_en: str,
    body_fr: str,
    summary_en: str = '',
    summary_fr: str = '',
    effective_at=None,
) -> LegalDocumentVersion:
    """Create a new current version (admin/staff tooling)."""
    with transaction.atomic():
        LegalDocumentVersion.objects.filter(
            document_type=document_type,
            is_current=True,
        ).update(is_current=False)
        return LegalDocumentVersion.objects.create(
            document_type=document_type,
            version=version,
            effective_at=effective_at or timezone.now(),
            is_current=True,
            body_en=body_en,
            body_fr=body_fr,
            summary_en=summary_en,
            summary_fr=summary_fr,
        )
