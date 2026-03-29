from django.test import TestCase
from django.contrib.auth import get_user_model
from ..models import Service, ServiceCategory, ServiceSubCategory
from ..admin import ServiceAdmin, ServiceCategoryAdmin, ServiceSubCategoryAdmin

User = get_user_model()


class ServiceAdminTests(TestCase):
    """Test cases for Service admin interface."""
    
    def setUp(self):
        """Set up test data."""
        self.user = User.objects.create_user(
            email='admin@example.com',
            username='admin',
            password='adminpass123'
        )
        
        self.category = ServiceCategory.objects.create(name='Massage')
        self.subcategory = ServiceSubCategory.objects.create(
            name='Swedish Massage',
            category=self.category
        )
        
        self.service = Service.objects.create(
            name='Swedish Massage',
            sub_category=self.subcategory,
            organization=None,  # Will be set properly in real tests
            description='Relaxing Swedish massage',
            price_min=50,
            price_max=100
        )
    
    def test_service_admin_list_display(self):
        """Test service admin list display fields."""
        admin = ServiceAdmin(Service, None)
        expected_fields = [
            'name', 'organization', 'sub_category', 'price_min',
            'price_max', 'is_active', 'featured', 'created_at'
        ]
        self.assertEqual(admin.list_display, expected_fields)
    
    def test_service_admin_search_fields(self):
        """Test service admin search fields."""
        admin = ServiceAdmin(Service, None)
        expected_fields = ['name', 'description', 'organization__name']
        self.assertEqual(admin.search_fields, expected_fields)
    
    def test_service_admin_list_filter(self):
        """Test service admin list filters."""
        admin = ServiceAdmin(Service, None)
        expected_filters = [
            'organization', 'sub_category', 'is_active', 'featured',
            'requires_verification', 'created_at'
        ]
        self.assertEqual(admin.list_filter, expected_filters)


class ServiceCategoryAdminTests(TestCase):
    """Test cases for ServiceCategory admin interface."""
    
    def setUp(self):
        """Set up test data."""
        self.category = ServiceCategory.objects.create(
            name='Massage',
            icon='spa',
            sort_order=1
        )
    
    def test_category_admin_list_display(self):
        """Test category admin list display fields."""
        admin = ServiceCategoryAdmin(ServiceCategory, None)
        expected_fields = ['name', 'icon', 'is_active', 'sort_order', 'created_at']
        self.assertEqual(admin.list_display, expected_fields)
    
    def test_category_admin_search_fields(self):
        """Test category admin search fields."""
        admin = ServiceCategoryAdmin(ServiceCategory, None)
        expected_fields = ['name', 'description']
        self.assertEqual(admin.search_fields, expected_fields)


class ServiceSubCategoryAdminTests(TestCase):
    """Test cases for ServiceSubCategory admin interface."""
    
    def setUp(self):
        """Set up test data."""
        self.category = ServiceCategory.objects.create(name='Massage')
        self.subcategory = ServiceSubCategory.objects.create(
            name='Swedish Massage',
            category=self.category,
            sort_order=1
        )
    
    def test_subcategory_admin_list_display(self):
        """Test subcategory admin list display fields."""
        admin = ServiceSubCategoryAdmin(ServiceSubCategory, None)
        expected_fields = [
            'name', 'category', 'is_active', 'sort_order', 'created_at'
        ]
        self.assertEqual(admin.list_display, expected_fields)
    
    def test_subcategory_admin_list_filter(self):
        """Test subcategory admin list filters."""
        admin = ServiceSubCategoryAdmin(ServiceSubCategory, None)
        expected_filters = ['category', 'is_active', 'created_at']
        self.assertEqual(admin.list_filter, expected_filters)
