from django.test import TestCase
from django.contrib.auth import get_user_model

from src.apps.organizations.models import (
    Organization,
    OrganizationTypeModel,
    OrganizationTypeSubCategory,
)

User = get_user_model()


class OrganizationTypeModelTests(TestCase):
    """Test cases for OrganizationTypeModel."""
    
    def test_organization_type_creation(self):
        """Test organization type creation."""
        org_type = OrganizationTypeModel.objects.create(
            name='spa',
            display_name='Spa',
            description='Wellness spa services'
        )
        self.assertEqual(org_type.name, 'spa')
        self.assertEqual(org_type.display_name, 'Spa')
        self.assertTrue(org_type.is_active)
        self.assertEqual(str(org_type), 'Spa')
    
    def test_organization_type_unique_name(self):
        """Test unique name constraint."""
        OrganizationTypeModel.objects.create(name='spa', display_name='Spa')
        
        # Should prevent duplicate name
        with self.assertRaises(Exception):
            OrganizationTypeModel.objects.create(name='spa', display_name='Spa 2')


class OrganizationModelTests(TestCase):
    """Test cases for Organization model."""
    
    def setUp(self):
        """Set up test data."""
        self.user = User.objects.create_user(
            email='test@example.com',
            username='testuser',
            password='testpass123',
            role=User.UserRole.CLIENT,
        )
        
        self.org_type = OrganizationTypeModel.objects.create(
            name='spa',
            display_name='Spa'
        )
        
        self.organization = Organization.objects.create(
            name='Test Spa',
            type=self.org_type,
            email='spa@example.com',
            phone='+1234567890',
            address='1 Main St',
            city='City',
            postal_code='00000',
            country='US',
            verification_status=Organization.VerificationStatus.PENDING,
        )
    
    def test_organization_creation(self):
        """Test organization creation."""
        self.assertEqual(self.organization.name, 'Test Spa')
        self.assertEqual(self.organization.type, self.org_type)
        self.assertEqual(self.organization.email, 'spa@example.com')
        self.assertFalse(self.organization.is_verified)
    
    def test_organization_str_representation(self):
        """Test string representation."""
        self.assertEqual(str(self.organization), 'Test Spa')
    
    def test_organization_verification_property(self):
        """Test is_verified property."""
        self.assertFalse(self.organization.is_verified)
        
        self.organization.verification_status = Organization.VerificationStatus.VERIFIED
        self.organization.save()
        self.assertTrue(self.organization.is_verified)
    
    def test_organization_unique_constraint(self):
        """Test unique email constraint with soft delete."""
        # Should allow creation with different email
        org2 = Organization.objects.create(
            name='Another Spa',
            type=self.org_type,
            email='another@example.com',
            address='2 Main St',
            city='City',
            postal_code='00000',
            country='US',
        )
        self.assertIsNotNone(org2)
        
        # Should prevent duplicate email
        with self.assertRaises(Exception):
            Organization.objects.create(
                name='Duplicate Spa',
                type=self.org_type,
                email='spa@example.com',
                address='3 Main St',
                city='City',
                postal_code='00000',
                country='US',
            )


class OrganizationTypeSubCategoryTests(TestCase):
    """Test cases for OrganizationTypeSubCategory model."""
    
    def setUp(self):
        """Set up test data."""
        self.org_type = OrganizationTypeModel.objects.create(
            name='spa',
            display_name='Spa'
        )
        
        # Import here to avoid circular imports
        from ..services.models import ServiceCategory, ServiceSubCategory
        
        self.category = ServiceCategory.objects.create(name='Massage')
        self.subcategory = ServiceSubCategory.objects.create(
            name='Swedish Massage',
            category=self.category
        )
    
    def test_organization_type_subcategory_creation(self):
        """Test organization type subcategory creation."""
        org_subcat = OrganizationTypeSubCategory.objects.create(
            organization_type=self.org_type,
            sub_category=self.subcategory,
            is_default=True
        )
        self.assertEqual(org_subcat.organization_type, self.org_type)
        self.assertEqual(org_subcat.sub_category, self.subcategory)
        self.assertTrue(org_subcat.is_default)
        expected = f"{self.org_type.display_name} - {self.subcategory.name}"
        self.assertEqual(str(org_subcat), expected)
    
    def test_organization_type_subcategory_unique_constraint(self):
        """Test unique constraint."""
        OrganizationTypeSubCategory.objects.create(
            organization_type=self.org_type,
            sub_category=self.subcategory
        )
        
        # Should prevent duplicate
        with self.assertRaises(Exception):
            OrganizationTypeSubCategory.objects.create(
                organization_type=self.org_type,
                sub_category=self.subcategory
            )


class OrganizationTypeKindTests(TestCase):
    """OrganizationTypeModel.Kind (catalogue constants, not a DB field)."""

    def test_organization_type_kind_choices(self):
        Kind = OrganizationTypeModel.Kind
        self.assertIn(Kind.HOTEL, dict(Kind.choices).values())
        self.assertIn(Kind.SPA, dict(Kind.choices).values())

    def test_organization_type_kind_values(self):
        Kind = OrganizationTypeModel.Kind
        self.assertEqual(Kind.HOTEL.value, 'H')
        self.assertEqual(Kind.HOTEL.label, 'Hotel')
