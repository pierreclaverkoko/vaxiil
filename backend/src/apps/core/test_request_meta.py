"""Tests for AuditEvent helpers and request meta."""

from __future__ import annotations

from decimal import Decimal
from unittest.mock import MagicMock

from django.contrib.auth import get_user_model
from django.test import RequestFactory, TestCase

from src.apps.core.audit import AuditEvent
from src.apps.core.request_meta import (
    BOOKING_CANCEL,
    client_ip_from_request,
    client_user_agent,
    create_audit_event,
    parse_client_location,
)

User = get_user_model()


class RequestMetaTests(TestCase):
    def setUp(self):
        self.factory = RequestFactory()

    def test_client_ip_from_x_forwarded_for(self):
        request = self.factory.get('/')
        request.META['HTTP_X_FORWARDED_FOR'] = '203.0.113.10, 10.0.0.1'
        request.META['REMOTE_ADDR'] = '127.0.0.1'
        self.assertEqual(client_ip_from_request(request), '203.0.113.10')

    def test_client_ip_from_remote_addr(self):
        request = self.factory.get('/')
        request.META['REMOTE_ADDR'] = '127.0.0.1'
        self.assertEqual(client_ip_from_request(request), '127.0.0.1')

    def test_client_user_agent_truncated(self):
        request = self.factory.get('/')
        request.META['HTTP_USER_AGENT'] = 'A' * 600
        self.assertEqual(len(client_user_agent(request)), 512)

    def test_parse_client_location_valid(self):
        loc = parse_client_location(
            {
                'client_latitude': '4.327600',
                'client_longitude': '15.313600',
                'client_location_accuracy_m': '12.5',
            }
        )
        self.assertEqual(loc['latitude'], Decimal('4.327600'))
        self.assertEqual(loc['longitude'], Decimal('15.313600'))
        self.assertEqual(loc['accuracy_m'], 12.5)

    def test_parse_client_location_incomplete_ignored(self):
        loc = parse_client_location({'client_latitude': '1.0'})
        self.assertIsNone(loc['latitude'])
        self.assertIsNone(loc['longitude'])

    def test_parse_client_location_out_of_range_ignored(self):
        loc = parse_client_location(
            {'client_latitude': '99', 'client_longitude': '0'}
        )
        self.assertIsNone(loc['latitude'])

    def test_create_audit_event_with_gps_from_request_data(self):
        user = User.objects.create_user(
            email='audit@example.com',
            username='audituser',
            password='ComplexPass123!',
        )
        request = MagicMock()
        request.META = {
            'REMOTE_ADDR': '198.51.100.1',
            'HTTP_USER_AGENT': 'TestAgent/1.0',
        }
        request.data = {
            'client_latitude': '-1.286389',
            'client_longitude': '36.817223',
            'client_location_accuracy_m': 8,
        }

        event = create_audit_event(request, user=user, action=BOOKING_CANCEL)
        self.assertEqual(event.action, BOOKING_CANCEL)
        self.assertEqual(event.ip_address, '198.51.100.1')
        self.assertEqual(event.user_agent, 'TestAgent/1.0')
        self.assertEqual(event.latitude, Decimal('-1.286389'))
        self.assertEqual(event.longitude, Decimal('36.817223'))
        self.assertEqual(event.location_accuracy_m, 8.0)
        self.assertEqual(AuditEvent.objects.count(), 1)
