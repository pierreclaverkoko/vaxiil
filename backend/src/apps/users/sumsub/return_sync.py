"""Process Sumsub WebSDK redirect return (JWT + applicant sync)."""

from __future__ import annotations

import logging
from typing import Any

import jwt
from django.conf import settings
from django.core.files.base import ContentFile
from django.db import transaction
from django.utils.translation import gettext as _

from src.apps.users.models import User, UserKycSumsubEvent
from src.apps.users.sumsub.client import (
    SumsubError,
    download_inspection_image,
    get_applicant_by_external_user_id,
    list_applicant_document_images,
)
from src.apps.users.sumsub.webhooks import (
    _apply_pending,
    _apply_rejected,
    _apply_verified,
)

logger = logging.getLogger(__name__)

_SELFIE_DOC_TYPES = frozenset({
    'SELFIE',
    'LIVENESS',
    'VIDEO_SELFIE',
    'PROFILE_IMAGE',
})

_ID_DOC_TYPES = frozenset({
    'PASSPORT',
    'ID_CARD',
    'DRIVERS',
    'RESIDENCE_PERMIT',
    'ID_DOC_PHOTO',
    'UTILITY_BILL',
    'OTHER',
})


class SumsubReturnError(ValueError):
    """Client-facing error while processing a Sumsub redirect return."""

    def __init__(self, message: str, *, code: str | None = None):
        super().__init__(message)
        self.code = code


def _redirect_sign_key() -> str:
    return getattr(settings, 'SUMSUB_REDIRECT_SIGN_KEY', '') or ''


def verify_redirect_jwt(*, token: str, user: User) -> dict[str, Any]:
    """Verify HS256 redirect JWT; require sub == user.pk and valid exp."""
    sign_key = _redirect_sign_key()
    if not token or not str(token).strip():
        raise SumsubReturnError(_('Sumsub redirect JWT is required.'))
    if not sign_key:
        raise SumsubReturnError(
            _('Sumsub redirect signing is not configured.')
        )
    try:
        payload = jwt.decode(
            str(token).strip(),
            sign_key,
            algorithms=['HS256'],
            options={
                'require': ['exp', 'sub'],
                'verify_aud': False,
            },
        )
    except jwt.ExpiredSignatureError as exc:
        raise SumsubReturnError(
            _('Sumsub redirect JWT has expired.'),
            code='sumsub_redirect_jwt_expired',
        ) from exc
    except jwt.InvalidTokenError as exc:
        raise SumsubReturnError(_('Sumsub redirect JWT is invalid.')) from exc

    sub = str(payload.get('sub') or '')
    if sub != str(user.pk):
        raise SumsubReturnError(_('Sumsub redirect JWT does not match this user.'))
    return payload


def _review_answer_from_applicant(applicant: dict[str, Any]) -> str:
    review = applicant.get('review') or {}
    result = review.get('reviewResult') or {}
    return str(result.get('reviewAnswer') or '').upper()


def _map_verification_status(
    *,
    review_answer: str,
    jwt_status: str,
) -> str | None:
    """Return V / R / P or None if no status change should be forced."""
    if review_answer == 'GREEN':
        return User.VerificationStatus.VERIFIED
    if review_answer == 'RED':
        return User.VerificationStatus.REJECTED
    jwt_s = (jwt_status or '').strip().lower()
    if jwt_s in ('approved', 'ok', 'green', 'completed'):
        return User.VerificationStatus.VERIFIED
    if jwt_s in ('rejected', 'reject', 'red', 'declined'):
        return User.VerificationStatus.REJECTED
    if jwt_s in ('pending', 'onhold', 'on_hold', 'resubmission'):
        return User.VerificationStatus.PENDING
    return None


def _image_id(meta: dict[str, Any]) -> str:
    for key in ('id', 'imageId', 'imageHash'):
        val = meta.get(key)
        if val is not None and str(val).strip():
            return str(val)
    return ''


def _doc_type(meta: dict[str, Any]) -> str:
    id_def = meta.get('idDocDef') or {}
    return str(id_def.get('idDocType') or meta.get('idDocType') or '').upper()


def _doc_subtype(meta: dict[str, Any]) -> str:
    id_def = meta.get('idDocDef') or {}
    return str(id_def.get('idDocSubType') or meta.get('idDocSubType') or '').upper()


def _ext_for_content_type(content_type: str) -> str:
    ct = (content_type or '').split(';')[0].strip().lower()
    mapping = {
        'image/jpeg': '.jpg',
        'image/jpg': '.jpg',
        'image/png': '.png',
        'image/webp': '.webp',
        'image/gif': '.gif',
        'application/pdf': '.pdf',
    }
    return mapping.get(ct, '.bin')


def _pick_images(
    items: list[dict[str, Any]],
) -> tuple[dict[str, Any] | None, dict[str, Any] | None]:
    """Return (id_doc_meta, selfie_meta) preferring FRONT identity docs."""
    id_candidates: list[dict[str, Any]] = []
    selfie_candidates: list[dict[str, Any]] = []
    for item in items:
        if not isinstance(item, dict):
            continue
        if not _image_id(item):
            continue
        dtype = _doc_type(item)
        if dtype in _SELFIE_DOC_TYPES or 'SELFIE' in dtype or 'LIVENESS' in dtype:
            selfie_candidates.append(item)
        elif dtype in _ID_DOC_TYPES or dtype:
            id_candidates.append(item)

    def front_first(meta: dict[str, Any]) -> tuple[int, str]:
        sub = _doc_subtype(meta)
        rank = 0 if sub == 'FRONT' else (1 if not sub else 2)
        return (rank, _image_id(meta))

    id_candidates.sort(key=front_first)
    id_meta = id_candidates[0] if id_candidates else None
    selfie_meta = selfie_candidates[0] if selfie_candidates else None
    return id_meta, selfie_meta


def _save_user_file(user: User, field_name: str, data: bytes, content_type: str) -> None:
    ext = _ext_for_content_type(content_type)
    filename = f'sumsub_{field_name}_{user.pk}{ext}'
    getattr(user, field_name).save(filename, ContentFile(data), save=False)


def _download_docs(
    *,
    applicant_id: str,
    inspection_id: str,
) -> tuple[tuple[bytes, str] | None, tuple[bytes, str] | None]:
    """Return (id_doc_bytes_ctype, selfie_bytes_ctype)."""
    if not applicant_id or not inspection_id:
        return None, None
    try:
        images = list_applicant_document_images(applicant_id)
        id_meta, selfie_meta = _pick_images(images)
    except SumsubError:
        logger.warning(
            'Sumsub list images failed applicant=%s',
            applicant_id,
            exc_info=True,
        )
        return None, None

    id_file = None
    selfie_file = None
    try:
        if id_meta:
            data, ctype = download_inspection_image(
                inspection_id=inspection_id,
                image_id=_image_id(id_meta),
            )
            id_file = (data, ctype)
        if selfie_meta:
            data, ctype = download_inspection_image(
                inspection_id=inspection_id,
                image_id=_image_id(selfie_meta),
            )
            selfie_file = (data, ctype)
    except SumsubError:
        logger.warning(
            'Sumsub document download failed applicant=%s',
            applicant_id,
            exc_info=True,
        )
    return id_file, selfie_file


def process_sumsub_return(
    user: User,
    *,
    jwt_token: str,
    status: str = '',
    sbx: bool = False,
) -> User:
    """
    Verify redirect JWT, fetch Sumsub applicant + images, persist history and files.

    Returns the refreshed User instance.
    """
    payload = verify_redirect_jwt(token=jwt_token, user=user)
    jwt_status = str(payload.get('status') or status or '')
    external_id = str(payload.get('sub') or user.pk)

    try:
        applicant = get_applicant_by_external_user_id(external_id)
    except SumsubError as exc:
        raise SumsubReturnError(
            _('Could not load Sumsub applicant data.')
        ) from exc

    applicant_id = str(
        applicant.get('id')
        or applicant.get('applicantId')
        or ''
    )
    inspection_id = str(
        applicant.get('inspectionId')
        or (applicant.get('review') or {}).get('inspectionId')
        or ''
    )
    review_answer = _review_answer_from_applicant(applicant)
    mapped = _map_verification_status(
        review_answer=review_answer,
        jwt_status=jwt_status,
    )
    id_file, selfie_file = _download_docs(
        applicant_id=applicant_id,
        inspection_id=inspection_id,
    )

    with transaction.atomic():
        user = User.objects.select_for_update().get(pk=user.pk)
        update_fields: list[str] = ['updated_at']

        if applicant_id and user.sumsub_applicant_id != applicant_id:
            user.sumsub_applicant_id = applicant_id
            update_fields.append('sumsub_applicant_id')

        UserKycSumsubEvent.objects.create(
            user=user,
            applicant_id=applicant_id,
            inspection_id=inspection_id,
            sandbox=bool(sbx),
            redirect_status=jwt_status[:64],
            review_answer=review_answer[:32],
            applicant_payload=applicant if isinstance(applicant, dict) else {},
        )

        previous_status = user.verification_status
        if mapped == User.VerificationStatus.VERIFIED:
            _apply_verified(user, update_fields)
        elif mapped == User.VerificationStatus.REJECTED:
            review = (applicant.get('review') or {}).get('reviewResult') or {}
            _apply_rejected(user, update_fields, review=review)
        elif mapped == User.VerificationStatus.PENDING:
            _apply_pending(user, update_fields, clear_rejection=False)

        if id_file:
            _save_user_file(user, 'id_document', id_file[0], id_file[1])
            update_fields.append('id_document')
        if selfie_file:
            _save_user_file(user, 'selfie_document', selfie_file[0], selfie_file[1])
            update_fields.append('selfie_document')

        user.save(update_fields=list(dict.fromkeys(update_fields)))

        if (
            mapped == User.VerificationStatus.VERIFIED
            and previous_status != User.VerificationStatus.VERIFIED
        ):
            from src.apps.staff.notify import notify_kyc_approved

            notify_kyc_approved(user=user)
        elif (
            mapped == User.VerificationStatus.REJECTED
            and previous_status != User.VerificationStatus.REJECTED
        ):
            from src.apps.staff.notify import notify_kyc_rejected

            notify_kyc_rejected(user=user, reason=user.rejection_reason)

    return User.objects.get(pk=user.pk)
