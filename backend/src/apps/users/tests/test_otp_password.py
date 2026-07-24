"""Email OTP login 2FA and password change/reset."""

from django.contrib.auth import get_user_model
from django.core import mail
from django.test import TestCase, override_settings
from rest_framework import status
from rest_framework.test import APIClient

from src.apps.users.otp_models import EmailOtp
from src.apps.users.otp_services import _hash_code, create_and_send_otp

User = get_user_model()


@override_settings(EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend')
class OtpPasswordApiTests(TestCase):
    def setUp(self):
        self.api = APIClient()
        self.user = User.objects.create_user(
            email='secure@example.com',
            username='secure',
            password='ComplexPass123!',
            two_factor_enabled=True,
        )

    def _code_from_mail(self):
        self.assertEqual(len(mail.outbox), 1)
        body = mail.outbox[0].body
        # "Your verification code is 123456."
        for token in body.split():
            if token.rstrip('.').isdigit() and len(token.rstrip('.')) == 6:
                return token.rstrip('.')
        self.fail(f'No OTP found in email body: {body!r}')

    def test_login_requires_otp_then_issues_tokens(self):
        res = self.api.post(
            '/api/v1/auth/login/',
            {'email': 'secure@example.com', 'password': 'ComplexPass123!'},
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(res.data['requires_otp'])
        challenge_id = res.data['challenge_id']
        code = self._code_from_mail()

        verify = self.api.post(
            '/api/v1/auth/login/verify-otp/',
            {'challenge_id': challenge_id, 'code': code},
            format='json',
        )
        self.assertEqual(verify.status_code, status.HTTP_200_OK)
        self.assertIn('access', verify.data)
        self.assertIn('refresh', verify.data)
        self.assertEqual(verify.data['user']['email'], 'secure@example.com')

    def test_password_change_with_otp(self):
        self.api.force_authenticate(user=self.user)
        send = self.api.post(
            '/api/v1/auth/otp/send/',
            {'purpose': 'password_change'},
            format='json',
        )
        self.assertEqual(send.status_code, status.HTTP_200_OK)
        code = self._code_from_mail()
        res = self.api.post(
            '/api/v1/auth/password/change/',
            {
                'current_password': 'ComplexPass123!',
                'new_password': 'EvenBetterPass456!',
                'challenge_id': send.data['challenge_id'],
                'code': code,
            },
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password('EvenBetterPass456!'))

    def test_password_reset_flow(self):
        req = self.api.post(
            '/api/v1/auth/password/reset/request/',
            {'email': 'secure@example.com'},
            format='json',
        )
        self.assertEqual(req.status_code, status.HTTP_200_OK)
        self.assertIn('challenge_id', req.data)
        code = self._code_from_mail()
        confirm = self.api.post(
            '/api/v1/auth/password/reset/confirm/',
            {
                'email': 'secure@example.com',
                'challenge_id': req.data['challenge_id'],
                'code': code,
                'new_password': 'ResetPass789!',
            },
            format='json',
        )
        self.assertEqual(confirm.status_code, status.HTTP_200_OK)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password('ResetPass789!'))

    def test_create_and_send_otp_hashes_code(self):
        otp = create_and_send_otp(
            email=self.user.email,
            purpose=EmailOtp.Purpose.LOGIN,
            user=self.user,
        )
        self.assertEqual(len(mail.outbox), 1)
        code = self._code_from_mail()
        self.assertEqual(otp.code_hash, _hash_code(code))
        self.assertNotEqual(otp.code_hash, code)

    def test_otp_email_includes_html_alternative(self):
        create_and_send_otp(
            email=self.user.email,
            purpose=EmailOtp.Purpose.LOGIN,
            user=self.user,
        )
        self.assertEqual(len(mail.outbox), 1)
        msg = mail.outbox[0]
        self.assertTrue(msg.alternatives)
        html = msg.alternatives[0][0]
        self.assertEqual(msg.alternatives[0][1], 'text/html')
        code = self._code_from_mail()
        self.assertIn(code, html)
        self.assertIn('VAXIIL', html.upper())

    def test_disable_two_factor_skips_login_otp(self):
        self.api.force_authenticate(user=self.user)
        updated = self.api.put(
            '/api/v1/auth/profile/',
            {'two_factor_enabled': False},
            format='json',
        )
        self.assertEqual(updated.status_code, status.HTTP_200_OK)
        self.assertFalse(updated.data['two_factor_enabled'])
        self.api.force_authenticate(user=None)
        mail.outbox.clear()
        res = self.api.post(
            '/api/v1/auth/login/',
            {'email': 'secure@example.com', 'password': 'ComplexPass123!'},
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertIn('access', res.data)
        self.assertFalse(res.data.get('requires_otp', False))
        self.assertEqual(len(mail.outbox), 0)
