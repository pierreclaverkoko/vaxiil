"""Sumsub webhook digest verification and applicant status updates."""

from __future__ import annotations

import hashlib
import hmac
import logging
from typing import Any

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from src.apps.users.models import User

logger = logging.getLogger(__name__)

_DIGEST_ALG = {
    'HMAC_SHA1_HEX': hashlib.sha1,
    'HMAC_SHA256_HEX': hashlib.sha256,
    'HMAC_SHA512_HEX': hashlib.sha512,
}

# Mid-flow / reset → verification_status PENDING
_PENDING_EVENTS = frozenset({
    'applicantPending',
    'applicantCreated',
    'applicantOnHold',
    'applicantAwaitingUser',
    'applicantAwaitingService',
    'applicantReset',
    'applicantStepsReset',
})

# Terminal review with reviewResult.reviewAnswer GREEN/RED
_REVIEW_EVENTS = frozenset({
    'applicantReviewed',
    'applicantWorkflowCompleted',
})

# Always treat as rejection (workflow failed)
_FAILED_EVENTS = frozenset({
    'applicantWorkflowFailed',
})


def _webhook_secret() -> str:
    return getattr(settings, 'SUMSUB_WEBHOOK_SECRET', '') or ''


def verify_webhook_digest(
    *,
    raw_body: bytes,
    digest_header: str,
    alg_header: str | None = None,
) -> bool:
    secret = _webhook_secret()
    if not secret or not digest_header:
        return False
    alg_name = (alg_header or 'HMAC_SHA256_HEX').strip().upper()
    digestmod = _DIGEST_ALG.get(alg_name)
    if digestmod is None:
        return False
    expected = hmac.new(
        secret.encode('utf-8'),
        raw_body,
        digestmod,
    ).hexdigest()
    return hmac.compare_digest(expected, digest_header.strip().lower())


def _rejection_reason(review_result: dict[str, Any] | None) -> str:
    if not review_result:
        return ''
    labels = review_result.get('rejectLabels') or []
    if labels:
        return ', '.join(str(x) for x in labels)
    reject_type = review_result.get('reviewRejectType') or ''
    return str(reject_type)


def _apply_pending(user: User, update_fields: list[str], *, clear_rejection: bool) -> None:
    user.verification_status = User.VerificationStatus.PENDING
    user.verified_at = None
    update_fields.extend(['verification_status', 'verified_at'])
    if clear_rejection:
        user.rejection_reason = ''
        update_fields.append('rejection_reason')


def _apply_verified(user: User, update_fields: list[str]) -> None:
    user.verification_status = User.VerificationStatus.VERIFIED
    user.verified_at = timezone.now()
    user.rejection_reason = ''
    update_fields.extend(
        ['verification_status', 'verified_at', 'rejection_reason']
    )


def _apply_rejected(
    user: User,
    update_fields: list[str],
    *,
    review: dict[str, Any] | None,
) -> str:
    reason = _rejection_reason(review)
    user.verification_status = User.VerificationStatus.REJECTED
    user.verified_at = None
    user.rejection_reason = reason
    update_fields.extend(
        ['verification_status', 'verified_at', 'rejection_reason']
    )
    return reason


def handle_sumsub_webhook(*, payload: dict[str, Any]) -> tuple[bool, str]:
    """
    Apply Sumsub applicant lifecycle to User.verification_status.

    Returns (ok, message). Signature must already be verified by the view.
    Unknown / action / KYT events are ACK'd without changing status.
    """
    event_type = payload.get('type') or ''
    external_user_id = payload.get('externalUserId') or ''
    applicant_id = payload.get('applicantId') or ''

    if not external_user_id:
        return True, 'ignored_no_external_user'

    try:
        user = User.objects.get(pk=external_user_id)
    except (User.DoesNotExist, ValueError, TypeError):
        logger.info(
            'Sumsub webhook for unknown externalUserId=%s type=%s',
            external_user_id,
            event_type,
        )
        return True, 'ignored_unknown_user'

    with transaction.atomic():
        user = User.objects.select_for_update().get(pk=user.pk)
        update_fields: list[str] = ['updated_at']

        if applicant_id and user.sumsub_applicant_id != applicant_id:
            user.sumsub_applicant_id = str(applicant_id)
            update_fields.append('sumsub_applicant_id')

        if event_type in _PENDING_EVENTS:
            clear_rejection = event_type in (
                'applicantReset',
                'applicantStepsReset',
            )
            _apply_pending(user, update_fields, clear_rejection=clear_rejection)
            user.save(update_fields=list(dict.fromkeys(update_fields)))
            return True, 'pending'

        if event_type in _FAILED_EVENTS:
            review = payload.get('reviewResult') or {}
            reason = _apply_rejected(user, update_fields, review=review)
            user.save(update_fields=list(dict.fromkeys(update_fields)))
            from src.apps.staff.notify import notify_kyc_rejected

            notify_kyc_rejected(user=user, reason=reason)
            return True, 'rejected'

        if event_type in _REVIEW_EVENTS:
            review = payload.get('reviewResult') or {}
            answer = (review.get('reviewAnswer') or '').upper()
            if answer == 'GREEN':
                _apply_verified(user, update_fields)
                user.save(update_fields=list(dict.fromkeys(update_fields)))
                from src.apps.staff.notify import notify_kyc_approved

                notify_kyc_approved(user=user)
                return True, 'verified'

            if answer == 'RED':
                reason = _apply_rejected(user, update_fields, review=review)
                user.save(update_fields=list(dict.fromkeys(update_fields)))
                from src.apps.staff.notify import notify_kyc_rejected

                notify_kyc_rejected(user=user, reason=reason)
                return True, 'rejected'

            user.save(update_fields=list(dict.fromkeys(update_fields)))
            return True, 'reviewed_ignored_answer'

        if applicant_id and 'sumsub_applicant_id' in update_fields:
            user.save(update_fields=list(dict.fromkeys(update_fields)))

    return True, 'ignored_event'
