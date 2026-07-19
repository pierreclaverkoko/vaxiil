"""Legal document versions and signup acceptance."""

from __future__ import annotations

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APIClient

from src.apps.users.legal_content import TERMS_EN, PRIVACY_EN
from src.apps.users.legal_models import LegalDocumentVersion, UserLegalAcceptance
from src.apps.users.legal_services import publish_version

User = get_user_model()


class LegalApiTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        now = timezone.now()
        cls.terms = LegalDocumentVersion.objects.create(
            document_type=LegalDocumentVersion.DocumentType.TERMS,
            version='2026.07.19',
            effective_at=now,
            is_current=True,
            body_en=TERMS_EN,
            body_fr='Conditions FR',
            summary_en='Terms summary',
            summary_fr='Résumé conditions',
        )
        cls.privacy = LegalDocumentVersion.objects.create(
            document_type=LegalDocumentVersion.DocumentType.PRIVACY,
            version='2026.07.19',
            effective_at=now,
            is_current=True,
            body_en=PRIVACY_EN,
            body_fr='Confidentialité FR',
            summary_en='Privacy summary',
            summary_fr='Résumé confidentialité',
        )

    def setUp(self):
        self.client = APIClient()

    def test_public_legal_document(self):
        res = self.client.get('/api/v1/legal/terms/?lang=en')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['version'], '2026.07.19')
        self.assertIn('VAXIIL', res.data['body'])

        res_fr = self.client.get('/api/v1/legal/privacy/?lang=fr')
        self.assertEqual(res_fr.status_code, status.HTTP_200_OK)
        self.assertEqual(res_fr.data['body'], 'Confidentialité FR')

    def test_metadata(self):
        res = self.client.get('/api/v1/auth/metadata/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['terms_version'], '2026.07.19')
        self.assertEqual(res.data['privacy_version'], '2026.07.19')

    def test_register_requires_acceptance(self):
        res = self.client.post(
            '/api/v1/auth/register/',
            {
                'email': 'new@example.com',
                'username': 'newuser',
                'password': 'ComplexPass123!',
                'password_confirm': 'ComplexPass123!',
            },
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

        res = self.client.post(
            '/api/v1/auth/register/',
            {
                'email': 'new@example.com',
                'username': 'newuser',
                'password': 'ComplexPass123!',
                'password_confirm': 'ComplexPass123!',
                'accepted_terms_version': '2026.07.19',
                'accepted_privacy_version': '2026.07.19',
            },
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        user = User.objects.get(email='new@example.com')
        self.assertEqual(UserLegalAcceptance.objects.filter(user=user).count(), 2)
        self.assertFalse(res.data['user']['legal']['needs_acceptance'])

    def test_reaccept_after_version_bump(self):
        user = User.objects.create_user(
            email='old@example.com',
            username='olduser',
            password='ComplexPass123!',
        )
        UserLegalAcceptance.objects.create(user=user, document=self.terms)
        UserLegalAcceptance.objects.create(user=user, document=self.privacy)

        publish_version(
            document_type=LegalDocumentVersion.DocumentType.TERMS,
            version='2026.08.01',
            body_en='New terms',
            body_fr='Nouvelles conditions',
        )
        self.client.force_authenticate(user)
        profile = self.client.get('/api/v1/auth/profile/')
        self.assertTrue(profile.data['legal']['needs_acceptance'])

        res = self.client.post(
            '/api/v1/auth/accept-legal/',
            {
                'accepted_terms_version': '2026.08.01',
                'accepted_privacy_version': '2026.07.19',
            },
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertFalse(res.data['legal']['needs_acceptance'])
