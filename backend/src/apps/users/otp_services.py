from __future__ import annotations

import hashlib
import secrets
from datetime import timedelta

from django.conf import settings
from django.utils import timezone
from django.utils.translation import gettext as _
from rest_framework.exceptions import ValidationError

from src.apps.notifications.email import send_templated_mail
from src.apps.users.otp_models import EmailOtp

OTP_TTL_MINUTES = 10
OTP_MAX_ATTEMPTS = 5
OTP_LENGTH = 6


def _hash_code(code: str) -> str:
    secret = getattr(settings, 'SECRET_KEY', '')
    return hashlib.sha256(f'{secret}:{code}'.encode('utf-8')).hexdigest()


def _generate_code() -> str:
    return ''.join(secrets.choice('0123456789') for _ in range(OTP_LENGTH))


def create_and_send_otp(
    *,
    email: str,
    purpose: str,
    user=None,
) -> EmailOtp:
    email = email.strip().lower()
    code = _generate_code()
    otp = EmailOtp.objects.create(
        user=user,
        email=email,
        purpose=purpose,
        code_hash=_hash_code(code),
        expires_at=timezone.now() + timedelta(minutes=OTP_TTL_MINUTES),
    )
    subject = _('Your Vaxiil verification code')
    send_templated_mail(
        to=email,
        subject=str(subject),
        template='otp',
        context={
            'eyebrow': _('Security code'),
            'headline': _('Your verification code'),
            'lede': _('Use this code to continue securely on Vaxiil.'),
            'greeting': _('Hello,'),
            'intro': _('Enter the code below to verify your identity.'),
            'code_label': _('Verification code'),
            'code': code,
            'expiry_note': _('This code expires in %(minutes)s minutes.')
            % {'minutes': OTP_TTL_MINUTES},
            'ignore_note': _(
                'If you did not request this, you can ignore this email.'
            ),
            'footer_note': _(
                'This message was sent because a verification code was requested for your account.'
            ),
        },
        fail_silently=False,
    )
    return otp


def verify_otp(
    *,
    challenge_id,
    code: str,
    purpose: str | None = None,
    email: str | None = None,
) -> EmailOtp:
    try:
        otp = EmailOtp.objects.select_related('user').get(pk=challenge_id)
    except (EmailOtp.DoesNotExist, ValueError, TypeError) as exc:
        raise ValidationError({'challenge_id': _('Invalid or expired code.')}) from exc

    if purpose and otp.purpose != purpose:
        raise ValidationError({'challenge_id': _('Invalid or expired code.')})
    if email and otp.email.lower() != email.strip().lower():
        raise ValidationError({'challenge_id': _('Invalid or expired code.')})
    if otp.consumed_at is not None:
        raise ValidationError({'code': _('This code was already used.')})
    if otp.expires_at < timezone.now():
        raise ValidationError({'code': _('This code has expired.')})
    if otp.attempts >= OTP_MAX_ATTEMPTS:
        raise ValidationError({'code': _('Too many attempts. Request a new code.')})

    otp.attempts += 1
    otp.save(update_fields=['attempts'])

    if not secrets.compare_digest(otp.code_hash, _hash_code(str(code).strip())):
        raise ValidationError({'code': _('Invalid verification code.')})

    otp.consumed_at = timezone.now()
    otp.save(update_fields=['consumed_at'])
    return otp
