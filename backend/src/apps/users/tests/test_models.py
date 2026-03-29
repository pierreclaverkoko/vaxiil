from django.test import TestCase
from django.contrib.auth import get_user_model
from .models import UserRole, VerificationStatus


User = get_user_model()


class UserModelTests(TestCase):
    def test_create_user(self):
        user = User.objects.create_user(
            email='test@example.com',
            username='testuser',
            password='testpass123',
            role=UserRole.CLIENT
        )
        self.assertEqual(user.email, 'test@example.com')
        self.assertEqual(user.role, UserRole.CLIENT)
        self.assertFalse(user.is_trusted)
        self.assertEqual(user.verification_status, VerificationStatus.PENDING)

    def test_generate_trust_alias(self):
        user = User.objects.create_user(
            email='test2@example.com',
            username='testuser2',
            password='testpass123',
            role=UserRole.CLIENT
        )
        alias = user.generate_trust_alias()
        self.assertIsNotNone(alias)
        self.assertEqual(user.trust_alias, alias)
        self.assertTrue('-' in alias)

    def test_is_verified_property(self):
        user = User.objects.create_user(
            email='test3@example.com',
            username='testuser3',
            password='testpass123',
            role=UserRole.CLIENT
        )
        self.assertFalse(user.is_verified)
        
        user.verification_status = VerificationStatus.VERIFIED
        user.save()
        self.assertTrue(user.is_verified)
