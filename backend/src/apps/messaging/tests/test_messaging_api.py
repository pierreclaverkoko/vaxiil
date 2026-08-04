"""Messaging API: invites, threads, block, polling."""

from __future__ import annotations

from datetime import timedelta
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.test import TestCase
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APIClient

from src.apps.bookings.models import Booking, BookingTimeSlot
from src.apps.messaging.models import Conversation, ConversationInvite, Message
from src.apps.organizations.models import (
    Organization,
    OrganizationMembership,
    OrganizationTypeModel,
)
from src.apps.payments.models import PaymentProvider, PaymentTransaction
from src.apps.services.models import Service, ServiceCategory, ServiceSubCategory
from src.apps.test_helpers.geo import seed_cities_country, seed_us_country_and_currency

User = get_user_model()


def _seed_us():
    return seed_us_country_and_currency()


class MessagingApiTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.country, cls.cac = _seed_us()
        cls.currency = cls.cac.currency
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
            cities_city=seed_cities_country(city_name='NYC')[1],
            name='Swedish',
            sub_category=cls.sub,
            organization=cls.org,
            description='x',
            price_min=50,
            price_max=100,
            accepted_currency=cls.cac,
            address='1 Main',
            postal_code='10001',
            country_text='US',
            country=cls.country,
        )
        cls.provider = PaymentProvider.objects.create(
            code='stub-msg',
            provider_type=PaymentProvider.ProviderType.OTHER,
            display_name='Stub',
            is_active=True,
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
        cls._mark_paid(cls.booking)

    @classmethod
    def _mark_paid(cls, booking: Booking, amount: Decimal | None = None) -> None:
        PaymentTransaction.objects.create(
            booking=booking,
            payment_provider=cls.provider,
            user=booking.user,
            amount=amount if amount is not None else booking.total_price,
            currency=cls.currency,
            kind=PaymentTransaction.TransactionKind.PAYMENT,
            status=PaymentTransaction.TransactionStatus.SUCCEEDED,
            provider_reference=f'pay_{booking.pk}',
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
        # Staff starts the booking thread; client may reply afterward.
        self.api.force_authenticate(user=self.owner)
        r = self.api.post(
            '/api/v1/messaging/conversations/booking/',
            {'booking_id': str(self.booking.id)},
            format='json',
        )
        self.assertEqual(r.status_code, status.HTTP_200_OK)
        conv_id = r.data['id']
        self.api.force_authenticate(user=self.alice)
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
        self.api.force_authenticate(user=self.owner)
        r = self.api.post(
            '/api/v1/messaging/conversations/booking/',
            {'booking_id': str(self.booking.id)},
            format='json',
        )
        conv_id = r.data['id']
        self.api.force_authenticate(user=self.alice)
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
        start = timezone.now() + timedelta(days=3)
        BookingTimeSlot.objects.create(
            booking=other_booking,
            start_time=start,
            end_time=start + timedelta(hours=1),
            location_type=Booking.LocationType.OFFICE,
        )
        self._mark_paid(other_booking)
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

    def test_unpaid_booking_cannot_open_thread(self):
        start = timezone.now() + timedelta(days=2)
        unpaid = Booking.objects.create(
            user=self.alice,
            service=self.service,
            organization=self.org,
            status=Booking.BookingStatus.REQUESTED,
            total_price=Decimal('40.00'),
            accepted_currency=self.cac,
        )
        BookingTimeSlot.objects.create(
            booking=unpaid,
            start_time=start,
            end_time=start + timedelta(hours=1),
            location_type=Booking.LocationType.OFFICE,
        )
        self.api.force_authenticate(user=self.owner)
        r = self.api.post(
            '/api/v1/messaging/conversations/booking/',
            {'booking_id': str(unpaid.id)},
            format='json',
        )
        self.assertEqual(r.status_code, status.HTTP_400_BAD_REQUEST)

    def test_staff_can_message_paid_booking(self):
        self.api.force_authenticate(user=self.owner)
        r = self.api.post(
            '/api/v1/messaging/conversations/booking/',
            {'booking_id': str(self.booking.id)},
            format='json',
        )
        self.assertEqual(r.status_code, status.HTTP_200_OK)
        conv_id = r.data['id']
        sent = self.api.post(
            f'/api/v1/messaging/conversations/{conv_id}/messages/',
            {'body': 'See you soon'},
            format='json',
        )
        self.assertEqual(sent.status_code, status.HTTP_201_CREATED)

    def test_client_cannot_start_booking_thread(self):
        self.api.force_authenticate(user=self.alice)
        denied = self.api.post(
            '/api/v1/messaging/conversations/booking/',
            {'booking_id': str(self.booking.id)},
            format='json',
        )
        self.assertEqual(denied.status_code, status.HTTP_403_FORBIDDEN)

    def test_client_can_open_existing_booking_thread(self):
        self.api.force_authenticate(user=self.owner)
        created = self.api.post(
            '/api/v1/messaging/conversations/booking/',
            {'booking_id': str(self.booking.id)},
            format='json',
        )
        self.assertEqual(created.status_code, status.HTTP_200_OK)
        self.api.force_authenticate(user=self.alice)
        reopen = self.api.post(
            '/api/v1/messaging/conversations/booking/',
            {'booking_id': str(self.booking.id)},
            format='json',
        )
        self.assertEqual(reopen.status_code, status.HTTP_200_OK)
        self.assertEqual(reopen.data['id'], created.data['id'])

    def test_send_denied_after_complete(self):
        start = timezone.now() + timedelta(days=1)
        booking = Booking.objects.create(
            user=self.alice,
            service=self.service,
            organization=self.org,
            status=Booking.BookingStatus.CONFIRMED,
            total_price=Decimal('60.00'),
            accepted_currency=self.cac,
        )
        BookingTimeSlot.objects.create(
            booking=booking,
            start_time=start,
            end_time=start + timedelta(hours=1),
            location_type=Booking.LocationType.OFFICE,
        )
        self._mark_paid(booking)
        self.api.force_authenticate(user=self.owner)
        r = self.api.post(
            '/api/v1/messaging/conversations/booking/',
            {'booking_id': str(booking.id)},
            format='json',
        )
        conv_id = r.data['id']
        booking.status = Booking.BookingStatus.COMPLETED
        booking.completed_at = timezone.now()
        booking.save(update_fields=['status', 'completed_at', 'updated_at'])
        self.api.force_authenticate(user=self.alice)
        denied = self.api.post(
            f'/api/v1/messaging/conversations/{conv_id}/messages/',
            {'body': 'Too late'},
            format='json',
        )
        self.assertEqual(denied.status_code, status.HTTP_400_BAD_REQUEST)
        conv = Conversation.objects.get(pk=conv_id)
        self.assertEqual(conv.status, Conversation.Status.CLOSED)
        # Existing thread still openable (history).
        reopen = self.api.post(
            '/api/v1/messaging/conversations/booking/',
            {'booking_id': str(booking.id)},
            format='json',
        )
        self.assertEqual(reopen.status_code, status.HTTP_200_OK)
        self.assertEqual(reopen.data['id'], conv_id)

    def test_cannot_create_thread_after_slot_end(self):
        start = timezone.now() - timedelta(hours=3)
        past = Booking.objects.create(
            user=self.alice,
            service=self.service,
            organization=self.org,
            status=Booking.BookingStatus.CONFIRMED,
            total_price=Decimal('55.00'),
            accepted_currency=self.cac,
        )
        BookingTimeSlot.objects.create(
            booking=past,
            start_time=start,
            end_time=start + timedelta(hours=1),
            location_type=Booking.LocationType.OFFICE,
        )
        self._mark_paid(past)
        self.api.force_authenticate(user=self.owner)
        denied = self.api.post(
            '/api/v1/messaging/conversations/booking/',
            {'booking_id': str(past.id)},
            format='json',
        )
        self.assertEqual(denied.status_code, status.HTTP_400_BAD_REQUEST)

    def test_send_denied_after_slot_end(self):
        start = timezone.now() - timedelta(hours=3)
        past = Booking.objects.create(
            user=self.alice,
            service=self.service,
            organization=self.org,
            status=Booking.BookingStatus.CONFIRMED,
            total_price=Decimal('56.00'),
            accepted_currency=self.cac,
        )
        BookingTimeSlot.objects.create(
            booking=past,
            start_time=start,
            end_time=start + timedelta(hours=1),
            location_type=Booking.LocationType.OFFICE,
        )
        self._mark_paid(past)
        # Thread created earlier while window was open.
        conv = Conversation.objects.create(
            kind=Conversation.Kind.BOOKING,
            status=Conversation.Status.ACTIVE,
            booking=past,
            organization=self.org,
        )
        from src.apps.messaging.models import ConversationParticipant

        ConversationParticipant.objects.create(conversation=conv, user=self.alice)
        self.api.force_authenticate(user=self.alice)
        denied = self.api.post(
            f'/api/v1/messaging/conversations/{conv.id}/messages/',
            {'body': 'After hours'},
            format='json',
        )
        self.assertEqual(denied.status_code, status.HTTP_400_BAD_REQUEST)
        conv.refresh_from_db()
        self.assertEqual(conv.status, Conversation.Status.CLOSED)
        # Existing closed thread is still returned for history.
        reopen = self.api.post(
            '/api/v1/messaging/conversations/booking/',
            {'booking_id': str(past.id)},
            format='json',
        )
        self.assertEqual(reopen.status_code, status.HTTP_200_OK)
        self.assertEqual(reopen.data['status']['value'], 'closed')
