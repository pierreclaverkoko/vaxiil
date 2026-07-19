from datetime import date, timedelta

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone

from src.apps.users.serializers import UserProfileSerializer

User = get_user_model()


class UserModelTests(TestCase):
    def test_coerce_role_accepts_legacy_client_string(self):
        self.assertEqual(User.coerce_role('CLIENT'), User.UserRole.CLIENT)
        self.assertEqual(User.coerce_role('C'), User.UserRole.CLIENT)

    def test_create_user(self):
        user = User.objects.create_user(
            email='test@example.com',
            username='testuser',
            password='testpass123',
            role=User.UserRole.CLIENT,
        )
        self.assertEqual(user.email, 'test@example.com')
        self.assertEqual(user.role, User.UserRole.CLIENT)
        self.assertFalse(user.is_trusted)
        self.assertEqual(user.verification_status, User.VerificationStatus.PENDING)

    def test_generate_trust_alias(self):
        user = User.objects.create_user(
            email='test2@example.com',
            username='testuser2',
            password='testpass123',
            role=User.UserRole.CLIENT,
        )
        alias = user.generate_trust_alias()
        self.assertIsNotNone(alias)
        self.assertEqual(user.trust_alias, alias)
        self.assertTrue('-' in alias)

    def test_regenerate_trust_alias_changes_value(self):
        user = User.objects.create_user(
            email='test2b@example.com',
            username='testuser2b',
            password='testpass123',
            role=User.UserRole.CLIENT,
        )
        first = user.generate_trust_alias()
        second = user.regenerate_trust_alias()
        self.assertNotEqual(first, second)
        self.assertEqual(user.trust_alias, second)

    def test_is_verified_property(self):
        user = User.objects.create_user(
            email='test3@example.com',
            username='testuser3',
            password='testpass123',
            role=User.UserRole.CLIENT,
        )
        self.assertFalse(user.is_verified)

        user.verification_status = User.VerificationStatus.VERIFIED
        user.save()
        self.assertTrue(user.is_verified)

    def test_age_is_computed_from_date_of_birth(self):
        today = timezone.localdate()
        user = User.objects.create_user(
            email='age@example.com',
            username='ageuser',
            password='testpass123',
            date_of_birth=date(today.year - 30, today.month, min(today.day, 28)),
        )

        self.assertEqual(user.age, 30)

    def test_profile_rejects_future_date_of_birth(self):
        user = User.objects.create_user(
            email='future@example.com',
            username='futureuser',
            password='testpass123',
        )
        serializer = UserProfileSerializer(
            user,
            data={'date_of_birth': timezone.localdate() + timedelta(days=1)},
            partial=True,
        )

        self.assertFalse(serializer.is_valid())
        self.assertIn('date_of_birth', serializer.errors)
