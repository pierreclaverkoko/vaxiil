from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from src.apps.organizations.models import (
    Organization,
    OrganizationMembership,
    OrganizationTypeModel,
)
from src.apps.services.models import (
    Service,
    ServiceCategory,
    ServiceMedia,
    ServiceSubCategory,
)
from src.apps.test_helpers.geo import seed_cities_country,  create_org_address, seed_us_country_and_currency

User = get_user_model()


class OrganizationProviderServiceAPITests(TestCase):
    """CRUD services under /organizations/{id}/services/."""

    @classmethod
    def setUpTestData(cls):
        cls.org_type = OrganizationTypeModel.objects.create(
            name='spa', display_name='Spa'
        )
        cls.country, cls.cac = seed_us_country_and_currency()
        cls.owner = User.objects.create_user(
            email='owner@example.com',
            username='owner',
            password='secret123',
            role=User.UserRole.BUSINESS_OWNER,
        )
        cls.organization = Organization.objects.create(
            name='Zen Spa',
            type=cls.org_type,
            email='zen@example.com',
            country=cls.country,
            default_currency=cls.cac,
            verification_status=Organization.VerificationStatus.VERIFIED,
        )
        create_org_address(cls.organization, cls.country)
        OrganizationMembership.objects.create(
            user=cls.owner,
            organization=cls.organization,
            role=OrganizationMembership.OrganizationMemberRole.OWNER,
        )
        cls.category = ServiceCategory.objects.create(
            name='Massage',
            icon='sparkles',
            is_active=True,
            sort_order=1,
        )
        cls.sub = ServiceSubCategory.objects.create(
            name='Swedish Massage',
            category=cls.category,
            is_active=True,
        )
        cls.service = Service.objects.create(
            cities_city=seed_cities_country(city_name='NYC')[1],
            
            name='Swedish Relaxation',
            sub_category=cls.sub,
            organization=cls.organization,
            description='Classic Swedish strokes',
            price_min=50,
            price_max=100,
            accepted_currency=cls.cac,
            is_active=True,
            featured=True,
            address='1 Main',
            postal_code='10001',
            country_text='US',
            country=cls.country,
        )

    def setUp(self):
        self.client = APIClient()
        token = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {token.access_token}')

    def test_list_org_services(self):
        r = self.client.get(
            f'/api/v1/organizations/{self.organization.id}/services/'
        )
        self.assertEqual(r.status_code, status.HTTP_200_OK)
        self.assertIn('results', r.data)
        names = {x['name'] for x in r.data['results']}
        self.assertIn('Swedish Relaxation', names)

    def test_create_service(self):
        r = self.client.post(
            f'/api/v1/organizations/{self.organization.id}/services/',
            {
                'name': 'Hot Stone',
                'sub_category': str(self.sub.id),
                'description': 'Heated stones',
                'price_min': '60.00',
                'price_max': '90.00',
                'accepted_currency': str(self.cac.id),
                'address': '1 Main',
                'city': 'NYC',
                'postal_code': '10001',
                'country_text': 'US',
                'country': str(self.country.id),
                'variants': [
                    {
                        'name': '60 min',
                        'duration_minutes': 60,
                        'duration_type': 'F',
                        'price': '75.00',
                        'is_popular': True,
                        'is_active': True,
                    }
                ],
            },
            format='json',
        )
        self.assertEqual(r.status_code, status.HTTP_201_CREATED, r.data)
        self.assertEqual(r.data['name'], 'Hot Stone')
        self.assertEqual(len(r.data['variants']), 1)
        # Price range is derived from variant prices, not the posted min/max.
        self.assertEqual(r.data['price_min'], '75.00')
        self.assertEqual(r.data['price_max'], '75.00')

    def test_create_service_choice_enum_writes(self):
        from src.apps.services.models import ServiceVariantModel

        r = self.client.post(
            f'/api/v1/organizations/{self.organization.id}/services/',
            {
                'name': 'Flexible Massage',
                'sub_category': str(self.sub.id),
                'description': 'Flexible duration',
                'accepted_currency': str(self.cac.id),
                'address': '1 Main',
                'postal_code': '10001',
                'country_text': 'US',
                'country': str(self.country.id),
                'availability_type': 'O',
                'variants': [
                    {
                        'name': 'Flexible',
                        'duration_minutes': 90,
                        'duration_type': 'X',
                        'price': '80.00',
                        'is_popular': False,
                        'is_active': True,
                    }
                ],
            },
            format='json',
        )
        self.assertEqual(r.status_code, status.HTTP_201_CREATED, r.data)
        self.assertEqual(r.data['availability_type']['value'], 'O')
        self.assertEqual(r.data['variants'][0]['duration_type']['value'], 'X')
        service = Service.objects.get(pk=r.data['id'])
        self.assertEqual(
            service.availability_type,
            Service.ServiceAvailabilityType.ON_DEMAND,
        )
        variant = service.variants.get()
        self.assertEqual(
            variant.duration_type,
            ServiceVariantModel.ServiceVariant.FLEXIBLE,
        )

    def test_unverified_org_forbidden(self):
        self.organization.verification_status = Organization.VerificationStatus.PENDING
        self.organization.save(update_fields=['verification_status'])
        r = self.client.get(
            f'/api/v1/organizations/{self.organization.id}/services/'
        )
        self.assertEqual(r.status_code, status.HTTP_403_FORBIDDEN)

    def test_upload_primary_image(self):
        image = SimpleUploadedFile(
            'cover.jpg',
            b'\xff\xd8\xff\xe0' + b'\x00' * 64,
            content_type='image/jpeg',
        )
        r = self.client.post(
            f'/api/v1/organizations/{self.organization.id}/services/'
            f'{self.service.id}/media/',
            {'file': image},
            format='multipart',
        )
        self.assertEqual(r.status_code, status.HTTP_200_OK, r.data)
        self.assertTrue(r.data.get('primary_image'))
        media = ServiceMedia.objects.filter(
            service=self.service, is_primary=True
        )
        self.assertEqual(media.count(), 1)
        self.assertEqual(
            media.get().media_type, ServiceMedia.ServiceMediaType.IMAGE
        )

    def test_upload_primary_image_requires_file(self):
        r = self.client.post(
            f'/api/v1/organizations/{self.organization.id}/services/'
            f'{self.service.id}/media/',
            {},
            format='multipart',
        )
        self.assertEqual(r.status_code, status.HTTP_400_BAD_REQUEST)
