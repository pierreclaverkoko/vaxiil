"""KYB submit endpoint URL matches mobile / documented kebab-case path."""

import uuid

from django.test import SimpleTestCase
from django.urls import reverse


class KybSubmitUrlTests(SimpleTestCase):
    def test_submit_verification_url_uses_kebab_case(self):
        pk = str(uuid.uuid4())
        path = reverse('organization-submit-verification', kwargs={'pk': pk})
        self.assertEqual(
            path, f'/api/v1/organizations/{pk}/submit-verification/'
        )
