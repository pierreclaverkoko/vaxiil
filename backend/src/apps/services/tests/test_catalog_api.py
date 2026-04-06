from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from src.apps.organizations.models import Organization, OrganizationTypeModel
from src.apps.services.models import Service, ServiceCategory, ServiceSubCategory
from src.apps.test_helpers.geo import create_org_address, seed_us_country_and_currency

User = get_user_model()


class ServiceCatalogAPITests(TestCase):
    """Authenticated catalog endpoints for categories and services."""

    @classmethod
    def setUpTestData(cls):
        cls.user = User.objects.create_user(
            email='client@example.com',
            username='client',
            password='secret123',
            role=User.UserRole.CLIENT,
        )
        cls.org_type = OrganizationTypeModel.objects.create(
            name='spa', display_name='Spa'
        )
        cls.country, cls.cac = seed_us_country_and_currency()
        cls.organization = Organization.objects.create(
            name='Zen Spa',
            type=cls.org_type,
            email='zen@example.com',
            country=cls.country,
            default_currency=cls.cac,
            verification_status=Organization.VerificationStatus.VERIFIED,
        )
        create_org_address(cls.organization, cls.country)
        cls.category = ServiceCategory.objects.create(
            name='Massage',
            icon='sparkles',
            is_active=True,
            sort_order=1,
        )
        cls.other_category = ServiceCategory.objects.create(
            name='Fitness',
            icon='bolt',
            is_active=True,
            sort_order=2,
        )
        cls.sub = ServiceSubCategory.objects.create(
            name='Swedish Massage',
            category=cls.category,
            is_active=True,
        )
        cls.other_sub = ServiceSubCategory.objects.create(
            name='Yoga',
            category=cls.other_category,
            is_active=True,
        )
        cls.service = Service.objects.create(
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
            city='NYC',
            postal_code='10001',
            country_text='US',
            country=cls.country,
        )
        cls.service_plain = Service.objects.create(
            name='Deep Tissue',
            sub_category=cls.sub,
            organization=cls.organization,
            description='Intense pressure',
            price_min=80,
            price_max=120,
            accepted_currency=cls.cac,
            is_active=True,
            featured=False,
            address='1 Main',
            city='NYC',
            postal_code='10001',
            country_text='US',
            country=cls.country,
        )
        cls.service_other_cat = Service.objects.create(
            name='Morning Yoga',
            sub_category=cls.other_sub,
            organization=cls.organization,
            description='Group session',
            price_min=20,
            price_max=20,
            accepted_currency=cls.cac,
            is_active=True,
            featured=False,
            address='1 Main',
            city='NYC',
            postal_code='10001',
            country_text='US',
            country=cls.country,
        )

    def setUp(self):
        self.client = APIClient()
        token = RefreshToken.for_user(self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {token.access_token}')

    def test_categories_requires_auth(self):
        self.client.credentials()
        r = self.client.get('/api/v1/services/categories/')
        self.assertEqual(r.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_categories_list(self):
        r = self.client.get('/api/v1/services/categories/')
        self.assertEqual(r.status_code, status.HTTP_200_OK)
        self.assertIn('results', r.data)
        names = {row['name'] for row in r.data['results']}
        self.assertIn('Massage', names)
        massage = next(x for x in r.data['results'] if x['name'] == 'Massage')
        self.assertEqual(massage['icon'], 'sparkles')

    def test_services_requires_auth(self):
        self.client.credentials()
        r = self.client.get('/api/v1/services/')
        self.assertEqual(r.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_services_list_shape(self):
        r = self.client.get('/api/v1/services/')
        self.assertEqual(r.status_code, status.HTTP_200_OK)
        self.assertIn('results', r.data)
        row = r.data['results'][0]
        self.assertIn('id', row)
        self.assertIn('organization', row)
        self.assertEqual(row['organization']['name'], 'Zen Spa')
        self.assertIn('sub_category', row)
        self.assertEqual(row['sub_category']['category']['name'], 'Massage')
        self.assertIn('primary_image', row)

    def test_services_search(self):
        r = self.client.get('/api/v1/services/', {'search': 'Swedish'})
        self.assertEqual(r.status_code, status.HTTP_200_OK)
        names = {x['name'] for x in r.data['results']}
        self.assertIn('Swedish Relaxation', names)
        self.assertNotIn('Morning Yoga', names)

    def test_services_featured_filter(self):
        r = self.client.get('/api/v1/services/', {'featured': 'true'})
        self.assertEqual(r.status_code, status.HTTP_200_OK)
        names = {x['name'] for x in r.data['results']}
        self.assertIn('Swedish Relaxation', names)
        self.assertNotIn('Deep Tissue', names)

    def test_services_category_filter(self):
        r = self.client.get(
            '/api/v1/services/', {'category': str(self.other_category.id)}
        )
        self.assertEqual(r.status_code, status.HTTP_200_OK)
        names = {x['name'] for x in r.data['results']}
        self.assertIn('Morning Yoga', names)
        self.assertNotIn('Swedish Relaxation', names)

    def test_service_retrieve_detail_shape(self):
        r = self.client.get(f'/api/v1/services/{self.service.id}/')
        self.assertEqual(r.status_code, status.HTTP_200_OK)
        self.assertEqual(r.data['name'], 'Swedish Relaxation')
        self.assertIn('availability_type', r.data)
        self.assertIn('variants', r.data)
        self.assertIn('media', r.data)
        self.assertIn('feature_mappings', r.data)
        self.assertIn('organization', r.data)
        self.assertIn('verification_status', r.data['organization'])
