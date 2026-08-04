"""Legal document versions and signup acceptance."""

from __future__ import annotations

from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from src.apps.users.legal_content import PRIVACY_EN, PRIVACY_FR
from src.apps.users.legal_models import LegalDocumentVersion, UserLegalAcceptance
from src.apps.users.legal_services import publish_version

User = get_user_model()

TURNSTILE_PRIVACY_ADDENDUM_URL = 'https://www.cloudflare.com/turnstile-privacy-policy/'
TERMS_VERSION = '2026.08.05'
PRIVACY_VERSION = '2026.08.04'


class LegalApiTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        # Terms seeded by 0018 (cancel/refund rules); privacy by 0017.
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
        self.client = APIClient()

    def test_public_legal_document(self):
        res = self.client.get('/api/v1/legal/terms/?lang=en')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['version'], TERMS_VERSION)
        self.assertIn('VAXIIL', res.data['body'])
        self.assertIn('BAP IMAGINE', res.data['body'])
        self.assertIn('info@bapimagine.com', res.data['body'])
        self.assertIn('store credit', res.data['body'].lower())
        self.assertIn('24 hours', res.data['body'])
        self.assertNotIn('Governing law', res.data['body'])
        self.assertNotIn('Democratic Republic of the Congo', res.data['body'])

        res_fr = self.client.get('/api/v1/legal/privacy/?lang=fr')
        self.assertEqual(res_fr.status_code, status.HTTP_200_OK)
        self.assertEqual(res_fr.data['version'], PRIVACY_VERSION)
        self.assertIn(TURNSTILE_PRIVACY_ADDENDUM_URL, res_fr.data['body'])
        self.assertIn('BAP IMAGINE', res_fr.data['body'])
        self.assertIn('info@bapimagine.com', res_fr.data['body'])
        self.assertNotIn('Droit applicable', res_fr.data['body'])

    def test_metadata(self):
        res = self.client.get('/api/v1/auth/metadata/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['terms_version'], TERMS_VERSION)
        self.assertEqual(res.data['privacy_version'], PRIVACY_VERSION)

    def test_register_requires_acceptance(self):
        res = self.client.post(
            '/api/v1/auth/register/',
            {
                'email': 'new@example.com',
                'username': 'newuser',
                'password': 'ComplexPass123!',
                'password_confirm': 'ComplexPass123!',
                'cf_turnstile_response': 'test-token',
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
                'accepted_terms_version': TERMS_VERSION,
                'accepted_privacy_version': PRIVACY_VERSION,
                'cf_turnstile_response': 'test-token',
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
            version='2026.09.01',
            body_en='New terms',
            body_fr='Nouvelles conditions',
        )
        self.client.force_authenticate(user)
        profile = self.client.get('/api/v1/auth/profile/')
        self.assertTrue(profile.data['legal']['needs_acceptance'])

        res = self.client.post(
            '/api/v1/auth/accept-legal/',
            {
                'accepted_terms_version': '2026.09.01',
                'accepted_privacy_version': PRIVACY_VERSION,
            },
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertFalse(res.data['legal']['needs_acceptance'])

    def test_current_privacy_references_turnstile_privacy_addendum(self):
        """Invisible Turnstile requires linking Cloudflare's Turnstile Privacy Addendum."""
        self.assertIn(TURNSTILE_PRIVACY_ADDENDUM_URL, PRIVACY_EN)
        self.assertIn(TURNSTILE_PRIVACY_ADDENDUM_URL, PRIVACY_FR)
        self.assertIn('Turnstile Privacy Addendum', PRIVACY_EN)
        self.assertIn('Addendum de confidentialité Turnstile', PRIVACY_FR)
        self.assertIn('invisible mode', PRIVACY_EN)
        self.assertIn('mode invisible', PRIVACY_FR)
        self.assertIn(TURNSTILE_PRIVACY_ADDENDUM_URL, self.privacy.body_en)
        self.assertIn(TURNSTILE_PRIVACY_ADDENDUM_URL, self.privacy.body_fr)
