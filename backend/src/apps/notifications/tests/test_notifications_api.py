"""Notifications list / mark-read API."""

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APIClient

from src.apps.notifications.models import Notification

User = get_user_model()


class NotificationsApiTests(TestCase):
    def setUp(self):
        self.api = APIClient()
        self.user = User.objects.create_user(
            email='notify@example.com',
            username='notify',
            password='pass12345',
        )
        self.other = User.objects.create_user(
            email='other-notify@example.com',
            username='othernotify',
            password='pass12345',
        )
        self.n1 = Notification.objects.create(
            user=self.user,
            kind=Notification.Kind.BOOKING_CONFIRMED,
            audience=Notification.Audience.PERSONAL,
            title='Confirmed',
            body='Your booking is confirmed.',
        )
        self.n2 = Notification.objects.create(
            user=self.user,
            kind=Notification.Kind.BOOKING_CANCELLED,
            audience=Notification.Audience.PERSONAL,
            title='Cancelled',
            body='Your booking was cancelled.',
        )
        Notification.objects.create(
            user=self.other,
            kind=Notification.Kind.BOOKING_RECEIVED,
            title='Other',
            body='Not yours.',
        )

    def test_list_own_notifications(self):
        self.api.force_authenticate(user=self.user)
        res = self.api.get('/api/v1/notifications/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        ids = {row['id'] for row in res.data['results']}
        self.assertIn(str(self.n1.id), ids)
        self.assertIn(str(self.n2.id), ids)
        self.assertEqual(len(res.data['results']), 2)

    def test_mark_read(self):
        self.api.force_authenticate(user=self.user)
        res = self.api.post(f'/api/v1/notifications/{self.n1.id}/mark-read/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertIsNotNone(res.data['read_at'])
        self.n1.refresh_from_db()
        self.assertIsNotNone(self.n1.read_at)

    def test_mark_all_read(self):
        self.api.force_authenticate(user=self.user)
        res = self.api.post('/api/v1/notifications/mark-all-read/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['updated'], 2)
        self.assertEqual(
            Notification.objects.filter(user=self.user, read_at__isnull=True).count(),
            0,
        )
        # Idempotent on already-read.
        self.n1.read_at = timezone.now()
        self.n1.save(update_fields=['read_at'])
