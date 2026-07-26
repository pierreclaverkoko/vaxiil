"""User profile sex read/write (ChoiceEnumField is read-only)."""

from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

User = get_user_model()


class UserProfileSexApiTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.user = User.objects.create_user(
            email='sex@example.com',
            username='sexuser',
            password='secret123',
        )

    def setUp(self):
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)

    def test_put_sex(self):
        res = self.client.put(
            '/api/v1/auth/profile/',
            {
                'first_name': '',
                'last_name': '',
                'sex': 'F',
            },
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['sex']['value'], 'F')
        self.user.refresh_from_db()
        self.assertEqual(self.user.sex, User.Sex.FEMALE)

    def test_put_sex_from_choice_object(self):
        res = self.client.put(
            '/api/v1/auth/profile/',
            {
                'first_name': '',
                'last_name': '',
                'sex': {'value': 'M', 'title': 'Male', 'css': 'info'},
            },
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['sex']['value'], 'M')
        self.user.refresh_from_db()
        self.assertEqual(self.user.sex, User.Sex.MALE)

    def test_clear_sex(self):
        self.user.sex = User.Sex.OTHER
        self.user.save(update_fields=['sex'])
        res = self.client.put(
            '/api/v1/auth/profile/',
            {
                'first_name': '',
                'last_name': '',
                'sex': None,
            },
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertIsNone(res.data['sex'])
        self.user.refresh_from_db()
        self.assertIsNone(self.user.sex)

    def test_invalid_sex(self):
        res = self.client.put(
            '/api/v1/auth/profile/',
            {
                'first_name': '',
                'last_name': '',
                'sex': 'Z',
            },
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('sex', res.data)
