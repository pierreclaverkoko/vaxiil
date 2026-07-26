from django.test import TestCase
from django.contrib.auth import get_user_model

from src.apps.organizations.models import Organization, OrganizationTypeModel
from src.apps.test_helpers.geo import seed_cities_country,  create_org_address, seed_us_country_and_currency
from src.apps.services.models import (
    ServiceCategory,
    ServiceSubCategory,
    Service,
    ServiceVariantModel,
    ServiceFeature,
    ServiceFeatureMapping,
)

User = get_user_model()


class ServiceCategoryTests(TestCase):
    """Test cases for ServiceCategory model."""
    
    def test_category_creation(self):
        """Test service category creation."""
        category = ServiceCategory.objects.create(
            name='Massage',
            description='All massage services',
            icon='massage-icon'
        )
        self.assertEqual(category.name, 'Massage')
        self.assertEqual(str(category), 'Massage')
        self.assertTrue(category.is_active)
    
    def test_category_ordering(self):
        """Test category ordering."""
        cat1 = ServiceCategory.objects.create(
            name='Wellness', sort_order=2
        )
        cat2 = ServiceCategory.objects.create(
            name='Massage', sort_order=1
        )
        
        categories = list(ServiceCategory.objects.all())
        self.assertEqual(categories[0].name, 'Massage')
        self.assertEqual(categories[1].name, 'Wellness')


class ServiceSubCategoryTests(TestCase):
    """Test cases for ServiceSubCategory model."""
    
    def setUp(self):
        """Set up test data."""
        self.category = ServiceCategory.objects.create(
            name='Massage',
            description='Massage services'
        )
    
    def test_subcategory_creation(self):
        """Test subcategory creation."""
        subcat = ServiceSubCategory.objects.create(
            name='Swedish Massage',
            category=self.category,
            description='Traditional Swedish massage',
            duration_options=[30, 60, 90]
        )
        self.assertEqual(subcat.name, 'Swedish Massage')
        self.assertEqual(subcat.category, self.category)
        self.assertEqual(str(subcat), 'Massage - Swedish Massage')
    
    def test_subcategory_unique_constraint(self):
        """Test unique constraint."""
        ServiceSubCategory.objects.create(
            name='Swedish Massage',
            category=self.category
        )
        
        # Should prevent duplicate name within same category
        with self.assertRaises(Exception):
            ServiceSubCategory.objects.create(
                name='Swedish Massage',
                category=self.category
            )


class ServiceTests(TestCase):
    """Test cases for Service model."""
    
    def setUp(self):
        """Set up test data."""
        self.user = User.objects.create_user(
            email='business@example.com',
            username='business',
            password='testpass123',
            role=User.UserRole.CLIENT,
        )
        self.org_type = OrganizationTypeModel.objects.create(name='spa', display_name='Spa')
        self.country, self.cac = seed_us_country_and_currency()
        self.organization = Organization.objects.create(
            name='Test Spa',
            type=self.org_type,
            email='spa@example.com',
            country=self.country,
            default_currency=self.cac,
        )
        create_org_address(
            self.organization,
            self.country,
            address='1 Main',
            city='C',
            postal_code='0',
        )
        self.category = ServiceCategory.objects.create(name='Massage')
        self.subcategory = ServiceSubCategory.objects.create(
            name='Swedish Massage',
            category=self.category
        )
    
    def test_service_creation(self):
        """Test service creation."""
        service = Service.objects.create(
            cities_city=seed_cities_country(city_name='C')[1],
            
            name='Swedish Massage',
            sub_category=self.subcategory,
            organization=self.organization,
            description='Relaxing Swedish massage',
            price_min=50,
            price_max=100,
            accepted_currency=self.cac,
            address='1 Main',
            postal_code='0',
            country_text='US',
            country=self.country,
        )
        self.assertEqual(service.name, 'Swedish Massage')
        self.assertEqual(service.organization, self.organization)
        self.assertTrue(service.is_active)
        self.assertFalse(service.featured)
    
    def test_service_str_representation(self):
        """Test string representation."""
        service = Service.objects.create(
            cities_city=seed_cities_country(city_name='C')[1],
            
            name='Hot Stone Massage',
            sub_category=self.subcategory,
            organization=self.organization,
            description='Hot stone therapy',
            price_min=80,
            price_max=120,
            accepted_currency=self.cac,
            address='1 Main',
            postal_code='0',
            country_text='US',
            country=self.country,
        )
        expected = f"Hot Stone Massage - {self.organization.name}"
        self.assertEqual(str(service), expected)


class ServiceVariantModelTests(TestCase):
    """Test cases for ServiceVariantModel."""
    
    def setUp(self):
        """Set up test data."""
        self.user = User.objects.create_user(
            email='business@example.com',
            username='business',
            password='testpass123',
            role=User.UserRole.CLIENT,
        )
        self.org_type = OrganizationTypeModel.objects.create(name='spa', display_name='Spa')
        self.country, self.cac = seed_us_country_and_currency()
        self.organization = Organization.objects.create(
            name='Test Spa',
            type=self.org_type,
            email='spa@example.com',
            country=self.country,
            default_currency=self.cac,
        )
        create_org_address(
            self.organization,
            self.country,
            address='1 Main',
            city='C',
            postal_code='0',
        )
        self.category = ServiceCategory.objects.create(name='Massage')
        self.subcategory = ServiceSubCategory.objects.create(
            name='Swedish Massage',
            category=self.category
        )
        self.service = Service.objects.create(
            cities_city=seed_cities_country(city_name='C')[1],
            
            name='Swedish Massage',
            sub_category=self.subcategory,
            organization=self.organization,
            description='x',
            price_min=50,
            price_max=100,
            accepted_currency=self.cac,
            address='1 Main',
            postal_code='0',
            country_text='US',
            country=self.country,
        )
    
    def test_variant_creation(self):
        """Test service variant creation."""
        variant = ServiceVariantModel.objects.create(
            service=self.service,
            name='30 Minutes',
            duration_minutes=30,
            duration_type=ServiceVariantModel.ServiceVariant.FIXED,
            price=60
        )
        self.assertEqual(variant.service, self.service)
        self.assertEqual(variant.duration_minutes, 30)
        self.assertEqual(variant.price, 60)
        self.assertFalse(variant.is_popular)
    
    def test_variant_duration_choices(self):
        """Test duration type choices."""
        SV = ServiceVariantModel.ServiceVariant
        self.assertEqual(SV.FIXED.value, 'F')
        self.assertEqual(SV.FLEXIBLE.value, 'X')
        self.assertEqual(SV.FIXED.label, 'Fixed Duration')


class ServiceFeatureTests(TestCase):
    """Test cases for ServiceFeature model."""
    
    def test_feature_creation(self):
        """Test service feature creation."""
        FT = ServiceFeature.ServiceFeatureType
        feature = ServiceFeature.objects.create(
            name='WiFi Available',
            feature_type=FT.AMENITY,
            description='Free WiFi for guests',
        )
        self.assertEqual(feature.name, 'WiFi Available')
        self.assertEqual(feature.feature_type, FT.AMENITY)

    def test_feature_type_choices(self):
        """Test feature type choices."""
        FT = ServiceFeature.ServiceFeatureType
        self.assertIn(FT.AMENITY, dict(FT.choices).values())
        self.assertIn(FT.REQUIREMENT, dict(FT.choices).values())
        self.assertIn(FT.SAFETY, dict(FT.choices).values())
