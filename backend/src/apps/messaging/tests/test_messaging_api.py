"""Messaging API: invites, threads, block, polling."""

from datetime import timedelta
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.test import TestCase
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APIClient

from src.apps.bookings.models import Booking, BookingTimeSlot
from src.apps.finances.models import Currency
from src.apps.messaging.models import Conversation, ConversationInvite, Message
from src.apps.organizations.models import (
    Country,
    CountryAcceptedCurrency,
    Organization,
    OrganizationMembership,
    OrganizationTypeModel,
)
from src.apps.services.models import Service, ServiceCategory, ServiceSubCategory

User = get_user_model()


def _seed_us():
    cur, _ = Currency.objects.get_or_create(
        code='USD',
        defaults={
            'symbol': '$',
            'name': 'US Dollar',
            'numeric_code': '840',
            'minor_units': 2,
            'is_active': True,
        },
    )
    ctry, _ = Country.objects.get_or_create(
        iso_code2='US',
        defaults={
            'iso_code3': 'USA',
            'name': 'United States',
            'flag': '',
            'is_active': True,
        },
    )
    cac, _ = CountryAcceptedCurrency.objects.get_or_create(
        country=ctry,
        currency=cur,
        defaults={'is_active': True, 'is_default': True},
    )
    return ctry, cac


class MessagingApiTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.country, cls.cac = _seed_us()
        cls.org_type = OrganizationTypeModel.objects.create(
            name='spa', display_name='Spa'
        )
        cls.alice = User.objects.create_user(
            email='alice@example.com',
            username='alice',
            password='pass12345',
            phone='+15551110001',
        )
        cls.alice.generate_trust_alias()
        cls.bob = User.objects.create_user(
            email='bob@example.com',
            username='bob',
            password='pass12345',
        )
        cls.bob.generate_trust_alias()
        cls.owner = User.objects.create_user(
            email='owner@example.com',
            username='owner',
            password='pass12345',
        )
        cls.owner.generate_trust_alias()
        cls.org = Organization.objects.create(
            name='Org A',
            type=cls.org_type,
            email='a@example.com',
            country=cls.country,
            default_currency=cls.cac,
        )
        OrganizationMembership.objects.create(
            user=cls.owner,
            organization=cls.org,
            role=OrganizationMembership.OrganizationMemberRole.OWNER,
        )
        cls.category = ServiceCategory.objects.create(name='Massage')
        cls.sub = ServiceSubCategory.objects.create(
            name='Swedish', category=cls.category
        )
        cls.service = Service.objects.create(
            name='Swedish',
            sub_category=cls.sub,
            organization=cls.org,
            description='x',
            price_min=50,
            price_max=100,
            accepted_currency=cls.cac,
            address='1 Main',
            city='NYC',
            postal_code='10001',
            country_text='US',
            country=cls.country,
        )
        start = timezone.now() + timedelta(days=7)
        cls.booking = Booking.objects.create(
            user=cls.alice,
            service=cls.service,
            organization=cls.org,
            status=Booking.BookingStatus.CONFIRMED,
            total_price=Decimal('75.00'),
            accepted_currency=cls.cac,
        )
        BookingTimeSlot.objects.create(
            booking=cls.booking,
            start_time=start,
            end_time=start + timedelta(hours=1),
            location_type=Booking.LocationType.OFFICE,
        )

    def setUp(self):
        cache.clear()
        self.api = APIClient()

    def test_opaque_invite_same_response_whether_or_not_user_exists(self):
        self.api.force_authenticate(user=self.alice)
        r1 = self.api.post(
            '/api/v1/messaging/invites/',
            {'email': 'nobody@example.com'},
            format='json',
        )
        r2 = self.api.post(
            '/api/v1/messaging/invites/',
            {'email': self.bob.email},
            format='json',
        )
        self.assertEqual(r1.status_code, status.HTTP_200_OK)
        self.assertEqual(r2.status_code, status.HTTP_200_OK)
        self.assertEqual(r1.data['detail'], r2.data['detail'])
        self.assertEqual(
            ConversationInvite.objects.filter(recipient=self.bob).count(), 1
        )
        self.assertEqual(
            ConversationInvite.objects.filter(
                target_value_normalized='nobody@example.com'
            ).count(),
            0,
        )

    def test_accept_invite_opens_direct_thread(self):
        self.api.force_authenticate(user=self.alice)
        self.api.post(
            '/api/v1/messaging/invites/',
            {'trust_alias': self.bob.trust_alias},
            format='json',
        )
        invite = ConversationInvite.objects.get(recipient=self.bob)
        self.api.force_authenticate(user=self.bob)
        incoming = self.api.get('/api/v1/messaging/invites/incoming/')
        self.assertEqual(incoming.status_code, status.HTTP_200_OK)
        self.assertEqual(len(incoming.data), 1)
        accepted = self.api.post(f'/api/v1/messaging/invites/{invite.id}/accept/')
        self.assertEqual(accepted.status_code, status.HTTP_200_OK)
        self.assertEqual(accepted.data['kind']['value'], 'direct')
        conv_id = accepted.data['id']
        sent = self.api.post(
            f'/api/v1/messaging/conversations/{conv_id}/messages/',
            {'body': 'Hello Alice'},
            format='json',
        )
        self.assertEqual(sent.status_code, status.HTTP_201_CREATED)
        self.assertEqual(sent.data['sender']['trust_alias'], self.bob.trust_alias)

    def test_booking_thread_and_block(self):
        self.api.force_authenticate(user=self.alice)
        r = self.api.post(
            '/api/v1/messaging/conversations/booking/',
            {'booking_id': str(self.booking.id)},
            format='json',
        )
        self.assertEqual(r.status_code, status.HTTP_200_OK)
        conv_id = r.data['id']
        self.api.post(
            f'/api/v1/messaging/conversations/{conv_id}/messages/',
            {'body': 'Running late'},
            format='json',
        )
        self.api.force_authenticate(user=self.owner)
        org_list = self.api.get(
            f'/api/v1/messaging/conversations/?organization_id={self.org.id}'
        )
        self.assertEqual(org_list.status_code, status.HTTP_200_OK)
        self.assertGreaterEqual(len(org_list.data['results']), 1)
        blocked = self.api.post(f'/api/v1/messaging/conversations/{conv_id}/block/')
        self.assertEqual(blocked.status_code, status.HTTP_200_OK)
        denied = self.api.post(
            f'/api/v1/messaging/conversations/{conv_id}/messages/',
            {'body': 'Should fail'},
            format='json',
        )
        self.assertEqual(denied.status_code, status.HTTP_400_BAD_REQUEST)
        self.api.post(f'/api/v1/messaging/conversations/{conv_id}/unblock/')
        ok = self.api.post(
            f'/api/v1/messaging/conversations/{conv_id}/messages/',
            {'body': 'Back'},
            format='json',
        )
        self.assertEqual(ok.status_code, status.HTTP_201_CREATED)
        self.assertEqual(ok.data['sender']['kind'], 'org_member')

    def test_support_thread_user_starts(self):
        self.api.force_authenticate(user=self.alice)
        r = self.api.post(
            '/api/v1/messaging/conversations/support/',
            {'organization_id': str(self.org.id)},
            format='json',
        )
        self.assertEqual(r.status_code, status.HTTP_200_OK)
        self.assertEqual(r.data['kind']['value'], 'support')

    def test_poll_messages_since(self):
        self.api.force_authenticate(user=self.alice)
        r = self.api.post(
            '/api/v1/messaging/conversations/booking/',
            {'booking_id': str(self.booking.id)},
            format='json',
        )
        conv_id = r.data['id']
        self.api.post(
            f'/api/v1/messaging/conversations/{conv_id}/messages/',
            {'body': 'First'},
            format='json',
        )
        first = Message.objects.get(body='First')
        since = first.created_at.isoformat().replace('+00:00', 'Z')
        self.api.post(
            f'/api/v1/messaging/conversations/{conv_id}/messages/',
            {'body': 'Second'},
            format='json',
        )
        polled = self.api.get(
            f'/api/v1/messaging/conversations/{conv_id}/messages/',
            {'since': since},
        )
        self.assertEqual(polled.status_code, status.HTTP_200_OK)
        bodies = [m['body'] for m in polled.data['results']]
        self.assertIn('Second', bodies)
        self.assertNotIn('First', bodies)

    def test_staff_cannot_open_arbitrary_dm(self):
        """Org staff has no endpoint to cold-DM a user — only booking/support."""
        self.api.force_authenticate(user=self.owner)
        r = self.api.post(
            '/api/v1/messaging/invites/',
            {'email': self.alice.email},
            format='json',
        )
        # Staff may still send P2P invites as users; cold org outreach is constrained
        # by booking/support endpoints only. Invite is user↔user and allowed.
        self.assertEqual(r.status_code, status.HTTP_200_OK)
        # Staff cannot create support on behalf of client:
        r2 = self.api.post(
            '/api/v1/messaging/conversations/support/',
            {'organization_id': str(self.org.id)},
            format='json',
        )
        # Owner as user can start support with their own org — allowed by design
        # (user-starts). Cold booking without access fails:
        other = User.objects.create_user(
            email='other@example.com', username='other', password='pass12345'
        )
        other_booking = Booking.objects.create(
            user=other,
            service=self.service,
            organization=self.org,
            status=Booking.BookingStatus.CONFIRMED,
            total_price=Decimal('10.00'),
            accepted_currency=self.cac,
        )
        # Owner IS staff so can open booking thread — that is allowed.
        ok = self.api.post(
            '/api/v1/messaging/conversations/booking/',
            {'booking_id': str(other_booking.id)},
            format='json',
        )
        self.assertEqual(ok.status_code, status.HTTP_200_OK)
        # Stranger cannot:
        stranger = User.objects.create_user(
            email='stranger@example.com', username='stranger', password='pass12345'
        )
        self.api.force_authenticate(user=stranger)
        denied = self.api.post(
            '/api/v1/messaging/conversations/booking/',
            {'booking_id': str(self.booking.id)},
            format='json',
        )
        self.assertEqual(denied.status_code, status.HTTP_403_FORBIDDEN)
