import base64

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase

from src.apps.organizations.models import OrganizationTypeModel
from src.apps.organizations.serializers import OrganizationCreateSerializer
from src.apps.test_helpers.geo import seed_us_country_and_currency

_ONE_PX_PNG = base64.b64decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
)


class OrganizationCreateSerializerTests(TestCase):
    def setUp(self):
        self.org_type = OrganizationTypeModel.objects.create(
            name='spa', display_name='Spa'
        )
        self.country, self.cac = seed_us_country_and_currency()

    def _base_payload(self):
        return {
            'type': str(self.org_type.id),
            'name': 'New Co',
            'email': 'newco@example.com',
            'phone': '',
            'description': '',
            'website': '',
            'country': str(self.country.id),
            'default_currency': str(self.cac.id),
            'address': '1 St',
            'city': 'Town',
            'postal_code': '00000',
            'country_text': '',
        }

    def test_create_without_logo_invalid(self):
        serializer = OrganizationCreateSerializer(data=self._base_payload())
        self.assertFalse(serializer.is_valid())
        self.assertIn('logo', serializer.errors)

    def test_create_with_logo_valid(self):
        logo = SimpleUploadedFile(
            'logo.png',
            _ONE_PX_PNG,
            content_type='image/png',
        )
        data = {**self._base_payload(), 'logo': logo}
        serializer = OrganizationCreateSerializer(data=data)
        self.assertTrue(serializer.is_valid(), serializer.errors)
