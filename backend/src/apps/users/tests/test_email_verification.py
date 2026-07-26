"""Email verification gate and welcome email."""

from __future__ import annotations

from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.core import mail
from django.test import TestCase, override_settings
from rest_framework import status
from rest_framework.test import APIClient

from src.apps.users.legal_models import LegalDocumentVersion

User = get_user_model()

TERMS_VERSION = '2026.07.19'
PRIVACY_VERSION = '2026.07.25'


@override_settings(
    EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend',
    EMAIL_VERIFICATION_REQUIRED=True,
)
class EmailVerificationApiTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.terms = LegalDocumentVersion.objects.get(
            document_type=LegalDocumentVersion.DocumentType.TERMS,
            version=TERMS_VERSION,
            is_current=True,
        )
        cls.privacy = LegalDocumentVersion.objects.get(
            document_type=LegalDocumentVersion.DocumentType.PRIVACY,
            version=PRIVACY_VERSION,
            is_current=True,
        )

    def setUp(self):
        self._turnstile = patch(
            'src.apps.core.fields.verify_turnstile_token',
            return_value=True,
        )
        self._turnstile.start()
        self.addCleanup(self._turnstile.stop)
        self.api = APIClient()

    def _code_from_mail(self, index: int = -1):
        self.assertGreaterEqual(len(mail.outbox), 1)
        body = mail.outbox[index].body
        for token in body.split():
            cleaned = token.rstrip('.:')
            if cleaned.isdigit() and len(cleaned) == 6:
                return cleaned
        self.fail(f'No OTP found in email body: {body!r}')

    def test_register_unverified_and_verify_sends_welcome(self):
        res = self.api.post(
            '/api/v1/auth/register/',
            {
                'email': 'fresh@example.com',
                'username': 'freshuser',
                'password': 'ComplexPass123!',
                'password_confirm': 'ComplexPass123!',
                'accepted_terms_version': TERMS_VERSION,
                'accepted_privacy_version': PRIVACY_VERSION,
                'cf_turnstile_response': 'test-token',
            },
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertTrue(res.data['user']['needs_email_verification'])
        self.assertFalse(res.data['user']['email_verified'])
        self.assertIn('challenge_id', res.data)
        self.assertGreaterEqual(len(mail.outbox), 1)

        user = User.objects.get(email='fresh@example.com')
        self.api.force_authenticate(user=user)

        blocked = self.api.get('/api/v1/bookings/')
        self.assertEqual(blocked.status_code, status.HTTP_403_FORBIDDEN)

        register_challenge = res.data['challenge_id']
        mail_count_after_register = len(mail.outbox)

        send = self.api.post('/api/v1/auth/email/verify/send/', {}, format='json')
        self.assertEqual(send.status_code, status.HTTP_200_OK)
        self.assertEqual(send.data['challenge_id'], register_challenge)
        self.assertFalse(send.data['resent'])
        self.assertEqual(len(mail.outbox), mail_count_after_register)

        challenge_id = send.data['challenge_id']
        code = self._code_from_mail()

        verify = self.api.post(
            '/api/v1/auth/email/verify/',
            {'challenge_id': challenge_id, 'code': code},
            format='json',
        )
        self.assertEqual(verify.status_code, status.HTTP_200_OK)
        self.assertTrue(verify.data['email_verified'])
        self.assertFalse(verify.data['needs_email_verification'])
        user.refresh_from_db()
        self.assertIsNotNone(user.email_verified_at)
        self.assertIsNotNone(user.welcome_email_sent_at)
        subjects = [m.subject for m in mail.outbox]
        self.assertTrue(any('Welcome' in s for s in subjects))

        ok = self.api.get('/api/v1/bookings/')
        self.assertEqual(ok.status_code, status.HTTP_200_OK)

    def test_soft_send_reuses_register_otp_force_resends(self):
        res = self.api.post(
            '/api/v1/auth/register/',
            {
                'email': 'reuse@example.com',
                'username': 'reuseuser',
                'password': 'ComplexPass123!',
                'password_confirm': 'ComplexPass123!',
                'accepted_terms_version': TERMS_VERSION,
                'accepted_privacy_version': PRIVACY_VERSION,
                'cf_turnstile_response': 'test-token',
            },
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        old_challenge = res.data['challenge_id']
        old_code = self._code_from_mail()
        user = User.objects.get(email='reuse@example.com')
        self.api.force_authenticate(user=user)

        soft = self.api.post('/api/v1/auth/email/verify/send/', {}, format='json')
        self.assertEqual(soft.data['challenge_id'], old_challenge)
        self.assertFalse(soft.data['resent'])

        force = self.api.post(
            '/api/v1/auth/email/verify/send/',
            {'force': True},
            format='json',
        )
        self.assertEqual(force.status_code, status.HTTP_200_OK)
        self.assertTrue(force.data['resent'])
        new_challenge = force.data['challenge_id']
        self.assertNotEqual(new_challenge, old_challenge)
        new_code = self._code_from_mail()
        self.assertNotEqual(new_code, old_code)

        stale = self.api.post(
            '/api/v1/auth/email/verify/',
            {'challenge_id': old_challenge, 'code': old_code},
            format='json',
        )
        self.assertEqual(stale.status_code, status.HTTP_400_BAD_REQUEST)

        spaced = f'{new_code[0]} {new_code[1]} {new_code[2:]}'
        verify = self.api.post(
            '/api/v1/auth/email/verify/',
            {'challenge_id': new_challenge, 'code': spaced},
            format='json',
        )
        self.assertEqual(verify.status_code, status.HTTP_200_OK)
        self.assertTrue(verify.data['email_verified'])

    def test_login_otp_marks_email_verified(self):
        user = User.objects.create_user(
            email='otpuser@example.com',
            username='otpuser',
            password='ComplexPass123!',
            two_factor_enabled=True,
        )
        self.assertIsNone(user.email_verified_at)

        res = self.api.post(
            '/api/v1/auth/login/',
            {
                'email': 'otpuser@example.com',
                'password': 'ComplexPass123!',
                'cf_turnstile_response': 'test-token',
            },
            format='json',
        )
        self.assertTrue(res.data['requires_otp'])
        code = self._code_from_mail()
        verify = self.api.post(
            '/api/v1/auth/login/verify-otp/',
            {
                'challenge_id': res.data['challenge_id'],
                'code': code,
                'cf_turnstile_response': 'test-token',
            },
            format='json',
        )
        self.assertEqual(verify.status_code, status.HTTP_200_OK)
        self.assertTrue(verify.data['user']['email_verified'])
        user.refresh_from_db()
        self.assertIsNotNone(user.email_verified_at)

    def test_grandfathered_user_is_verified(self):
        # Users created after migration with explicit null would need verify;
        # factory create_user leaves email_verified_at null unless set.
        # Existing migration grandfathers rows present at migrate time.
        user = User.objects.create_user(
            email='legacy@example.com',
            username='legacy',
            password='ComplexPass123!',
        )
        # Simulate grandfathered account
        from django.utils import timezone

        user.email_verified_at = timezone.now()
        user.save(update_fields=['email_verified_at'])
        self.api.force_authenticate(user=user)
        res = self.api.get('/api/v1/bookings/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
