from django.test import TestCase
from django.contrib.auth import get_user_model
from ..models import Organization, OrganizationTypeModel
from ..admin import OrganizationAdmin, OrganizationTypeModelAdmin

User = get_user_model()


class OrganizationAdminTests(TestCase):
    """Test cases for Organization admin interface."""
    
    def setUp(self):
        """Set up test data."""
        self.user = User.objects.create_user(
            email='admin@example.com',
            username='admin',
            password='adminpass123'
        )
        
        self.org_type = OrganizationTypeModel.objects.create(
            name='spa',
            display_name='Spa'
        )
        
        self.organization = Organization.objects.create(
            name='Test Spa',
            type=self.org_type,
            email='spa@example.com',
            phone='+1234567890'
        )
    
    def test_organization_admin_list_display(self):
        """Test organization admin list display fields."""
        admin = OrganizationAdmin(Organization, None)
        expected_fields = [
            'name', 'type', 'email', 'phone', 'is_verified', 'created_at'
        ]
        self.assertEqual(admin.list_display, expected_fields)
    
    def test_organization_admin_search_fields(self):
        """Test organization admin search fields."""
        admin = OrganizationAdmin(Organization, None)
        expected_fields = ['name', 'email', 'phone']
        self.assertEqual(admin.search_fields, expected_fields)
    
    def test_organization_admin_list_filter(self):
        """Test organization admin list filters."""
        admin = OrganizationAdmin(Organization, None)
        expected_filters = ['type', 'is_verified', 'created_at']
        self.assertEqual(admin.list_filter, expected_filters)


class OrganizationTypeModelAdminTests(TestCase):
    """Test cases for OrganizationTypeModel admin interface."""
    
    def setUp(self):
        """Set up test data."""
        self.org_type = OrganizationTypeModel.objects.create(
            name='spa',
            display_name='Spa',
            description='Wellness spa services'
        )
    
    def test_org_type_admin_list_display(self):
        """Test organization type admin list display fields."""
        admin = OrganizationTypeModelAdmin(OrganizationTypeModel, None)
        expected_fields = ['display_name', 'name', 'is_active', 'created_at']
        self.assertEqual(admin.list_display, expected_fields)
    
    def test_org_type_admin_search_fields(self):
        """Test organization type admin search fields."""
        admin = OrganizationTypeModelAdmin(OrganizationTypeModel, None)
        expected_fields = ['name', 'display_name', 'description']
        self.assertEqual(admin.search_fields, expected_fields)
