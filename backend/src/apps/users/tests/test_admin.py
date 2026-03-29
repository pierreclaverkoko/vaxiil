from django.test import TestCase
from django.utils import timezone
from django.contrib.auth import get_user_model
from ..models import User as CustomUser

User = get_user_model()


class UserModelTests(TestCase):
    """Test cases for User model."""
    
    def setUp(self):
        """Set up test data."""
        self.user = User.objects.create_user(
            email='test@example.com',
            username='testuser',
            password='testpass123',
            first_name='Test',
            last_name='User'
        )
    
    def test_user_creation(self):
        """Test user creation."""
        self.assertEqual(self.user.email, 'test@example.com')
        self.assertEqual(self.user.username, 'testuser')
        self.assertEqual(self.user.first_name, 'Test')
        self.assertEqual(self.user.last_name, 'User')
        self.assertFalse(self.user.is_staff)
        self.assertFalse(self.user.is_superuser)
    
    def test_user_str_representation(self):
        """Test user string representation."""
        expected = f"{self.user.first_name} {self.user.last_name}"
        self.assertEqual(str(self.user), expected)
    
    def test_user_trust_alias_generation(self):
        """Test trust alias generation."""
        self.assertIsNotNone(self.user.trust_alias)
        self.assertTrue(len(self.user.trust_alias) > 0)
    
    def test_user_is_verified_property(self):
        """Test is_verified property."""
        self.assertFalse(self.user.is_verified)
        
        self.user.verified_at = timezone.now()
        self.user.save()
        self.assertTrue(self.user.is_verified)
