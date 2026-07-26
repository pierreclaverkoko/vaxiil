"""Sumsub access-token, websdk-link, and webhook APIs."""

from __future__ import annotations

import hashlib
import hmac
import json
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from rest_framework import status
from rest_framework.test import APIClient

User = get_user_model()


def _digest(secret: str, raw: bytes, alg: str = 'sha256') -> str:
    return hmac.new(secret.encode('utf-8'), raw, getattr(hashlib, alg)).hexdigest()


@override_settings(SUMSUB_WEBHOOK_SECRET='whsec_sumsub_test')
class SumsubKycApiTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.user = User.objects.create_user(
            email='kycsum@example.com',
            username='kycsum',
            password='secret123',
        )

    def setUp(self):
        self.api = APIClient()
        self.api.force_authenticate(user=self.user)

    @patch('src.apps.users.views.create_access_token')
    def test_access_token(self, mock_create):
        mock_create.return_value = {
            'token': 'sdk-token-1',
            'userId': str(self.user.pk),
        }
        res = self.api.post('/api/v1/auth/kyc/sumsub/access-token/', {}, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK, res.data)
        self.assertEqual(res.data['token'], 'sdk-token-1')
        mock_create.assert_called_once()

    @patch('src.apps.users.views.create_websdk_link')
    def test_websdk_link(self, mock_link):
        mock_link.return_value = {'url': 'https://api.sumsub.com/idensic/l/#/abc'}
        res = self.api.post('/api/v1/auth/kyc/sumsub/websdk-link/', {}, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK, res.data)
        self.assertEqual(res.data['url'], 'https://api.sumsub.com/idensic/l/#/abc')
        self.user.refresh_from_db()
        self.assertEqual(
            self.user.verification_status,
            User.VerificationStatus.PENDING,
        )

    @override_settings(SUMSUB_SEND_PERSONAL_DATA=False)
    @patch('src.apps.users.sumsub.client._request')
    def test_websdk_link_omits_personal_data_when_disabled(self, mock_request):
        from src.apps.users.sumsub.client import create_websdk_link

        mock_request.return_value = {'url': 'https://api.sumsub.com/idensic/l/#/x'}
        self.user.phone = '+15551212'
        self.user.save(update_fields=['phone'])
        create_websdk_link(
            user=self.user,
            success_url='https://app.example/ok',
            reject_url='https://app.example/reject',
        )
        body = mock_request.call_args.kwargs['body']
        self.assertNotIn('applicantIdentifiers', body)

    @override_settings(SUMSUB_SEND_PERSONAL_DATA=True)
    @patch('src.apps.users.sumsub.client._request')
    def test_websdk_link_includes_personal_data_when_enabled(self, mock_request):
        from src.apps.users.sumsub.client import create_websdk_link

        mock_request.return_value = {'url': 'https://api.sumsub.com/idensic/l/#/x'}
        self.user.phone = '+15551212'
        self.user.save(update_fields=['phone'])
        create_websdk_link(
            user=self.user,
            success_url='https://app.example/ok',
            reject_url='https://app.example/reject',
        )
        body = mock_request.call_args.kwargs['body']
        self.assertEqual(
            body['applicantIdentifiers'],
            {'email': self.user.email, 'phone': '+15551212'},
        )

    @override_settings(SUMSUB_REDIRECT_SIGN_KEY='redirect-sign-test')
    @patch('src.apps.users.sumsub.client._request')
    def test_websdk_link_includes_sign_key_and_jwt_params(self, mock_request):
        from src.apps.users.sumsub.client import create_websdk_link

        mock_request.return_value = {'url': 'https://api.sumsub.com/idensic/l/#/x'}
        create_websdk_link(
            user=self.user,
            success_url='https://app.example/ok?status=ok',
            reject_url='https://app.example/reject?status=reject',
        )
        body = mock_request.call_args.kwargs['body']
        self.assertEqual(body['redirect']['signKey'], 'redirect-sign-test')
        allowed = body['redirect']['allowedQueryParams']
        self.assertIn('status', allowed)
        self.assertIn('jwt', allowed)
        self.assertIn('sbx', allowed)

    @patch('src.apps.users.sumsub.client._request')
    def test_websdk_link_includes_customization_name(self, mock_request):
        from src.apps.users.sumsub.client import create_websdk_link

        mock_request.return_value = {'url': 'https://api.sumsub.com/idensic/l/#/x'}
        create_websdk_link(
            user=self.user,
            success_url='https://app.example/ok',
            reject_url='https://app.example/reject',
            lang='fr',
        )
        query = mock_request.call_args.kwargs['query']
        self.assertEqual(query['lang'], 'fr')
        self.assertEqual(query['customizationName'], 'vaxiil-web')

    @override_settings(SUMSUB_CUSTOMIZATION_NAME='')
    @patch('src.apps.users.sumsub.client._request')
    def test_websdk_link_omits_empty_customization_name(self, mock_request):
        from src.apps.users.sumsub.client import create_websdk_link

        mock_request.return_value = {'url': 'https://api.sumsub.com/idensic/l/#/x'}
        create_websdk_link(
            user=self.user,
            success_url='https://app.example/ok',
            reject_url='https://app.example/reject',
        )
        query = mock_request.call_args.kwargs.get('query')
        if query:
            self.assertNotIn('customizationName', query)

    @patch('src.apps.users.sumsub.client._request')
    def test_get_applicant_by_external_user_id_path(self, mock_request):
        from src.apps.users.sumsub.client import get_applicant_by_external_user_id

        mock_request.return_value = {'id': 'app_1'}
        get_applicant_by_external_user_id(str(self.user.pk))
        path = mock_request.call_args.args[1]
        self.assertEqual(
            path,
            f'/resources/applicants/-;externalUserId={self.user.pk}/one',
        )

    def test_webhook_rejects_bad_signature(self):
        raw = json.dumps({'type': 'applicantReviewed'}).encode('utf-8')
        res = self.client.post(
            '/api/v1/auth/webhooks/sumsub/',
            data=raw,
            content_type='application/json',
            HTTP_X_PAYLOAD_DIGEST='deadbeef',
            HTTP_X_PAYLOAD_DIGEST_ALG='HMAC_SHA256_HEX',
        )
        self.assertEqual(res.status_code, status.HTTP_401_UNAUTHORIZED)

    @patch('src.apps.staff.notify.notify_kyc_approved')
    def test_webhook_applicant_reviewed_green(self, mock_notify):
        payload = {
            'type': 'applicantReviewed',
            'externalUserId': str(self.user.pk),
            'applicantId': 'app_123',
            'reviewResult': {'reviewAnswer': 'GREEN'},
        }
        raw = json.dumps(payload, separators=(',', ':')).encode('utf-8')
        sig = _digest('whsec_sumsub_test', raw)
        res = self.client.post(
            '/api/v1/auth/webhooks/sumsub/',
            data=raw,
            content_type='application/json',
            HTTP_X_PAYLOAD_DIGEST=sig,
            HTTP_X_PAYLOAD_DIGEST_ALG='HMAC_SHA256_HEX',
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK, res.data)
        self.user.refresh_from_db()
        self.assertEqual(
            self.user.verification_status,
            User.VerificationStatus.VERIFIED,
        )
        self.assertEqual(self.user.sumsub_applicant_id, 'app_123')
        self.assertIsNotNone(self.user.verified_at)
        mock_notify.assert_called_once()

    @patch('src.apps.staff.notify.notify_kyc_rejected')
    def test_webhook_applicant_reviewed_red(self, mock_notify):
        payload = {
            'type': 'applicantReviewed',
            'externalUserId': str(self.user.pk),
            'applicantId': 'app_456',
            'reviewResult': {
                'reviewAnswer': 'RED',
                'rejectLabels': ['BAD_PROOF_OF_IDENTITY'],
                'reviewRejectType': 'RETRY',
            },
        }
        raw = json.dumps(payload, separators=(',', ':')).encode('utf-8')
        sig = _digest('whsec_sumsub_test', raw)
        res = self.client.post(
            '/api/v1/auth/webhooks/sumsub/',
            data=raw,
            content_type='application/json',
            HTTP_X_PAYLOAD_DIGEST=sig,
            HTTP_X_PAYLOAD_DIGEST_ALG='HMAC_SHA256_HEX',
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK, res.data)
        self.user.refresh_from_db()
        self.assertEqual(
            self.user.verification_status,
            User.VerificationStatus.REJECTED,
        )
        self.assertIn('BAD_PROOF_OF_IDENTITY', self.user.rejection_reason)
        mock_notify.assert_called_once()

    def _post_webhook(self, payload: dict) -> None:
        raw = json.dumps(payload, separators=(',', ':')).encode('utf-8')
        sig = _digest('whsec_sumsub_test', raw)
        res = self.client.post(
            '/api/v1/auth/webhooks/sumsub/',
            data=raw,
            content_type='application/json',
            HTTP_X_PAYLOAD_DIGEST=sig,
            HTTP_X_PAYLOAD_DIGEST_ALG='HMAC_SHA256_HEX',
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK, res.data)

    def test_webhook_pending_like_example_payloads(self):
        """applicantCreated / OnHold / AwaitingUser → PENDING (Sumsub examples)."""
        for event_type, applicant_id in (
            ('applicantCreated', '5c9e177b0a975a6eeccf5960'),
            ('applicantOnHold', '5c7791f80a975a1df426b9e9'),
            ('applicantAwaitingUser', '5c7791f80a975a1df426b9e9'),
        ):
            with self.subTest(event_type=event_type):
                self.user.verification_status = User.VerificationStatus.REJECTED
                self.user.rejection_reason = 'old'
                self.user.save(
                    update_fields=[
                        'verification_status',
                        'rejection_reason',
                        'updated_at',
                    ]
                )
                self._post_webhook(
                    {
                        'applicantId': applicant_id,
                        'inspectionId': 'insp',
                        'applicantType': 'individual',
                        'correlationId': 'req-test',
                        'levelName': 'basic-kyc-level',
                        'externalUserId': str(self.user.pk),
                        'type': event_type,
                        'sandboxMode': False,
                        'reviewStatus': 'pending',
                        'createdAtMs': '2020-02-21 13:23:19.002',
                        'clientId': 'coolClientId',
                    }
                )
                self.user.refresh_from_db()
                self.assertEqual(
                    self.user.verification_status,
                    User.VerificationStatus.PENDING,
                )
                self.assertEqual(self.user.sumsub_applicant_id, applicant_id)

    @patch('src.apps.staff.notify.notify_kyc_rejected')
    def test_webhook_workflow_completed_red_example(self, mock_notify):
        payload = {
            'applicantId': '64106d6b7d5a2d5159e6b01a',
            'inspectionId': '64106d6b7d5a2d5159e6b01b',
            'applicantType': 'individual',
            'correlationId': 'req-57fed49a-07b8-4413-bdaa-a1be903769e9',
            'levelName': 'id-and-liveness',
            'sandboxMode': False,
            'externalUserId': str(self.user.pk),
            'type': 'applicantWorkflowCompleted',
            'reviewResult': {
                'reviewAnswer': 'RED',
                'rejectLabels': ['AGE_REQUIREMENT_MISMATCH'],
                'reviewRejectType': 'FINAL',
                'buttonIds': [],
            },
            'reviewStatus': 'completed',
            'workflowRevision': 8,
            'createdAt': '2023-03-14 12:50:27+0000',
            'createdAtMs': '2023-03-14 12:50:27.238',
            'clientId': 'coolClientId',
        }
        self._post_webhook(payload)
        self.user.refresh_from_db()
        self.assertEqual(
            self.user.verification_status,
            User.VerificationStatus.REJECTED,
        )
        self.assertIn('AGE_REQUIREMENT_MISMATCH', self.user.rejection_reason)
        mock_notify.assert_called_once()

    @patch('src.apps.staff.notify.notify_kyc_rejected')
    def test_webhook_workflow_failed_example(self, mock_notify):
        payload = {
            'applicantId': '64106d6b7d5a2d5159e6b01a',
            'inspectionId': '64106d6b7d5a2d5159e6b01b',
            'applicantType': 'individual',
            'correlationId': 'req-57fed49a-07b8-4413-bdaa-a1be903769e9',
            'levelName': 'id-and-liveness',
            'sandboxMode': False,
            'externalUserId': str(self.user.pk),
            'type': 'applicantWorkflowFailed',
            'reviewResult': {
                'reviewAnswer': 'RED',
                'rejectLabels': ['AGE_REQUIREMENT_MISMATCH'],
                'reviewRejectType': 'FINAL',
                'buttonIds': [],
            },
            'reviewStatus': 'completed',
            'workflowRevision': 8,
            'createdAt': '2023-03-14 12:50:27+0000',
            'createdAtMs': '2023-03-14 12:50:27.238',
            'clientId': 'coolClientId',
        }
        self._post_webhook(payload)
        self.user.refresh_from_db()
        self.assertEqual(
            self.user.verification_status,
            User.VerificationStatus.REJECTED,
        )
        mock_notify.assert_called_once()

    def test_webhook_applicant_reset_clears_verified(self):
        from django.utils import timezone

        self.user.verification_status = User.VerificationStatus.VERIFIED
        self.user.verified_at = timezone.now()
        self.user.rejection_reason = ''
        self.user.save(
            update_fields=[
                'verification_status',
                'verified_at',
                'rejection_reason',
                'updated_at',
            ]
        )
        self._post_webhook(
            {
                'applicantId': '5f194e74040c3f316bda271c',
                'inspectionId': '5f194e74040c3f316bda271d',
                'applicantType': 'individual',
                'correlationId': 'req-57fed49a-07b8-4413-bdaa-a1be903769e9',
                'levelName': 'id-and-liveness',
                'externalUserId': str(self.user.pk),
                'type': 'applicantReset',
                'sandboxMode': False,
                'reviewResult': {'reviewAnswer': 'GREEN'},
                'reviewStatus': 'init',
                'createdAtMs': '2021-03-01 11:34:51.104',
                'clientId': 'coolClientId',
            }
        )
        self.user.refresh_from_db()
        self.assertEqual(
            self.user.verification_status,
            User.VerificationStatus.PENDING,
        )
        self.assertIsNone(self.user.verified_at)
        self.assertEqual(self.user.rejection_reason, '')

    def test_webhook_kyt_without_external_user_ignored(self):
        before = self.user.verification_status
        self._post_webhook(
            {
                'applicantId': '670f85df0578a72bf1131856',
                'correlationId': 'da9564f4437c9fcd059f99e0b94fa04d',
                'sandboxMode': True,
                'type': 'kytCaseV2Created',
                'reviewStatus': 'open',
                'kytCaseStage': 'review',
                'kytCaseBlueprintId': '6717a1b20578a72bf11340aa',
                'kytCasePriority': 'medium',
                'createdAt': '2024-11-18 10:49:47+0000',
                'createdAtMs': '2024-11-18 10:49:47.918',
                'kytCaseId': '670f85e00578a72bf113189d',
            }
        )
        self.user.refresh_from_db()
        self.assertEqual(self.user.verification_status, before)

    def test_webhook_action_reviewed_ignored_status(self):
        self.user.verification_status = User.VerificationStatus.PENDING
        self.user.save(update_fields=['verification_status', 'updated_at'])
        self._post_webhook(
            {
                'applicantId': '5dc158b109494c3cbf431e28',
                'applicantActionId': '5dc2d80ce3cc9b1c1e389c4c',
                'externalApplicantActionId': 'id122424234-random-r7otyykndi',
                'inspectionId': '5dc158b109494c3cbf431e29',
                'applicantType': 'individual',
                'correlationId': 'req-c9041677-e8dc-446b-ab8f-50b438a40aa8',
                'levelName': 'basic-action-level',
                'externalUserId': str(self.user.pk),
                'type': 'applicantActionReviewed',
                'sandboxMode': False,
                'reviewResult': {'reviewAnswer': 'GREEN'},
                'reviewStatus': 'completed',
                'createdAtMs': '2020-02-21 13:23:19.001',
                'clientId': 'coolClientId',
            }
        )
        self.user.refresh_from_db()
        self.assertEqual(
            self.user.verification_status,
            User.VerificationStatus.PENDING,
        )
        self.assertEqual(
            self.user.sumsub_applicant_id,
            '5dc158b109494c3cbf431e28',
        )


def _redirect_jwt(
    *,
    user_id: str,
    status: str = 'approved',
    secret: str = 'sumsub_redirect_sign_key_test_32b',
    exp_offset: int = 600,
):
    import time

    import jwt as pyjwt

    now = int(time.time())
    return pyjwt.encode(
        {
            'iat': now - 120 if exp_offset < 0 else now,
            'exp': now + exp_offset,
            'sub': user_id,
            'aud': 'example.com',
            'status': status,
        },
        secret,
        algorithm='HS256',
    )


@override_settings(SUMSUB_REDIRECT_SIGN_KEY='sumsub_redirect_sign_key_test_32b')
class SumsubReturnApiTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.user = User.objects.create_user(
            email='kycreturn@example.com',
            username='kycreturn',
            password='secret123',
        )

    def setUp(self):
        self.api = APIClient()
        self.api.force_authenticate(user=self.user)

    def test_return_rejects_invalid_jwt(self):
        res = self.api.post(
            '/api/v1/auth/kyc/sumsub/return/',
            {'jwt': 'not-a-jwt', 'status': 'ok', 'sbx': True},
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

    def test_return_rejects_expired_jwt_with_code(self):
        token = _redirect_jwt(user_id=str(self.user.pk), exp_offset=-60)
        res = self.api.post(
            '/api/v1/auth/kyc/sumsub/return/',
            {'jwt': token, 'status': 'ok', 'sbx': True},
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(res.data['code'], 'sumsub_redirect_jwt_expired')
        self.assertIn('expired', str(res.data['detail']).lower())

    def test_return_rejects_sub_mismatch(self):
        other = User.objects.create_user(
            email='otherkyc@example.com',
            username='otherkyc',
            password='secret123',
        )
        token = _redirect_jwt(user_id=str(other.pk))
        res = self.api.post(
            '/api/v1/auth/kyc/sumsub/return/',
            {'jwt': token, 'status': 'ok', 'sbx': True},
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

    @patch('src.apps.staff.notify.notify_kyc_approved')
    @patch('src.apps.users.sumsub.return_sync.download_inspection_image')
    @patch('src.apps.users.sumsub.return_sync.list_applicant_document_images')
    @patch('src.apps.users.sumsub.return_sync.get_applicant_by_external_user_id')
    def test_return_success_saves_event_files_and_status(
        self,
        mock_applicant,
        mock_list,
        mock_download,
        mock_notify,
    ):
        from src.apps.users.models import UserKycSumsubEvent

        mock_applicant.return_value = {
            'id': 'app_ret_1',
            'inspectionId': 'insp_1',
            'review': {
                'reviewResult': {'reviewAnswer': 'GREEN'},
            },
        }
        mock_list.return_value = [
            {
                'id': 'img_id_1',
                'idDocDef': {'idDocType': 'PASSPORT', 'idDocSubType': 'FRONT'},
            },
            {
                'id': 'img_selfie_1',
                'idDocDef': {'idDocType': 'SELFIE'},
            },
        ]
        mock_download.side_effect = [
            (b'id-bytes', 'image/jpeg'),
            (b'selfie-bytes', 'image/jpeg'),
        ]
        token = _redirect_jwt(user_id=str(self.user.pk), status='approved')
        res = self.api.post(
            '/api/v1/auth/kyc/sumsub/return/',
            {'jwt': token, 'status': 'ok', 'sbx': True},
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK, res.data)
        self.user.refresh_from_db()
        self.assertEqual(
            self.user.verification_status,
            User.VerificationStatus.VERIFIED,
        )
        self.assertEqual(self.user.sumsub_applicant_id, 'app_ret_1')
        self.assertTrue(bool(self.user.id_document))
        self.assertTrue(bool(self.user.selfie_document))
        event = UserKycSumsubEvent.objects.get(user=self.user)
        self.assertEqual(event.applicant_id, 'app_ret_1')
        self.assertEqual(event.inspection_id, 'insp_1')
        self.assertTrue(event.sandbox)
        self.assertEqual(event.review_answer, 'GREEN')
        mock_notify.assert_called_once()
        self.assertEqual(res.data['verification_status']['value'], 'V')
