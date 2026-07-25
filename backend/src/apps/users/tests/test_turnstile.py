"""TurnstileField and guest-auth siteverify gating."""

from __future__ import annotations

import json
from unittest.mock import patch
from urllib.error import URLError

from django.contrib.auth import get_user_model
from django.test import RequestFactory, SimpleTestCase, TestCase, override_settings
from rest_framework import serializers
from rest_framework.test import APIClient, APIRequestFactory

from src.apps.core.fields import TurnstileField
from src.apps.core.request_meta import client_ip_from_request
from src.apps.core.turnstile import verify_turnstile_token

User = get_user_model()


class ClientIpTests(SimpleTestCase):
    def test_prefers_x_forwarded_for(self):
        request = RequestFactory().get('/')
        request.META['HTTP_X_FORWARDED_FOR'] = '203.0.113.10, 10.0.0.1'
        request.META['REMOTE_ADDR'] = '127.0.0.1'
        self.assertEqual(client_ip_from_request(request), '203.0.113.10')

    def test_falls_back_to_remote_addr(self):
        request = RequestFactory().get('/')
        request.META['REMOTE_ADDR'] = '127.0.0.1'
        self.assertEqual(client_ip_from_request(request), '127.0.0.1')


@override_settings(TURNSTILE_SECRET='test-turnstile-secret')
class VerifyTurnstileTokenTests(SimpleTestCase):
    @patch('src.apps.core.turnstile.urllib.request.urlopen')
    def test_success_true(self, mock_urlopen):
        mock_urlopen.return_value.__enter__.return_value.read.return_value = (
            json.dumps({'success': True}).encode('utf-8')
        )
        self.assertTrue(verify_turnstile_token('tok', remote_ip='1.2.3.4'))
        req = mock_urlopen.call_args[0][0]
        self.assertEqual(
            req.full_url,
            'https://challenges.cloudflare.com/turnstile/v0/siteverify',
        )
        body = req.data.decode('utf-8')
        self.assertIn('secret=test-turnstile-secret', body)
        self.assertIn('response=tok', body)
        self.assertIn('remoteip=1.2.3.4', body)

    @patch('src.apps.core.turnstile.urllib.request.urlopen')
    def test_success_false(self, mock_urlopen):
        mock_urlopen.return_value.__enter__.return_value.read.return_value = (
            json.dumps(
                {'success': False, 'error-codes': ['invalid-input-response']}
            ).encode('utf-8')
        )
        self.assertFalse(verify_turnstile_token('bad'))

    @override_settings(TURNSTILE_SECRET='')
    def test_empty_secret_fails(self):
        self.assertFalse(verify_turnstile_token('tok'))

    @patch('src.apps.core.turnstile.urllib.request.urlopen', side_effect=URLError('down'))
    def test_network_error_fails(self, _mock_urlopen):
        self.assertFalse(verify_turnstile_token('tok'))


class _TurnstileProbeSerializer(serializers.Serializer):
    cf_turnstile_response = TurnstileField()


@override_settings(TURNSTILE_SECRET='test-turnstile-secret')
class TurnstileFieldTests(SimpleTestCase):
    @patch('src.apps.core.fields.verify_turnstile_token', return_value=True)
    def test_valid_token(self, _mock_verify):
        request = APIRequestFactory().post('/')
        ser = _TurnstileProbeSerializer(
            data={'cf_turnstile_response': 'good-token'},
            context={'request': request},
        )
        self.assertTrue(ser.is_valid(), ser.errors)
        self.assertEqual(ser.validated_data['cf_turnstile_response'], 'good-token')

    @patch('src.apps.core.fields.verify_turnstile_token', return_value=False)
    def test_invalid_token(self, _mock_verify):
        ser = _TurnstileProbeSerializer(
            data={'cf_turnstile_response': 'bad-token'},
            context={'request': APIRequestFactory().post('/')},
        )
        self.assertFalse(ser.is_valid())
        self.assertIn('cf_turnstile_response', ser.errors)


@override_settings(TURNSTILE_SECRET='test-turnstile-secret')
class TurnstileAuthApiTests(TestCase):
    def setUp(self):
        self.api = APIClient()
        self.user = User.objects.create_user(
            email='turnstile@example.com',
            username='turnstileuser',
            password='ComplexPass123!',
        )

    def test_login_rejects_missing_turnstile(self):
        res = self.api.post(
            '/api/v1/auth/login/',
            {'email': 'turnstile@example.com', 'password': 'ComplexPass123!'},
            format='json',
        )
        self.assertEqual(res.status_code, 400)
        self.assertIn('cf_turnstile_response', res.data)

    @patch('src.apps.core.fields.verify_turnstile_token', return_value=False)
    def test_login_rejects_failed_turnstile(self, _mock_verify):
        res = self.api.post(
            '/api/v1/auth/login/',
            {
                'email': 'turnstile@example.com',
                'password': 'ComplexPass123!',
                'cf_turnstile_response': 'bad',
            },
            format='json',
        )
        self.assertEqual(res.status_code, 400)
        self.assertIn('cf_turnstile_response', res.data)

    @patch('src.apps.core.fields.verify_turnstile_token', return_value=True)
    def test_login_accepts_valid_turnstile(self, _mock_verify):
        res = self.api.post(
            '/api/v1/auth/login/',
            {
                'email': 'turnstile@example.com',
                'password': 'ComplexPass123!',
                'cf_turnstile_response': 'ok-token',
            },
            format='json',
        )
        self.assertEqual(res.status_code, 200)
        self.assertIn('access', res.data)
