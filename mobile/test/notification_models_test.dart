import 'package:flutter_test/flutter_test.dart';
import 'package:vaxiil_mobile/features/notifications/data/notification_models.dart';

void main() {
  test('NotificationModel parses API shape', () {
    final m = NotificationModel.fromJson({
      'id': 'n1',
      'kind': 'booking_confirmed',
      'title': 'Booking Confirmed',
      'body': 'Your session is confirmed.',
      'booking': 'b-42',
      'read_at': null,
      'email_sent_at': '2026-07-20T10:00:00Z',
      'created_at': '2026-07-20T09:30:00Z',
    });

    expect(m.id, 'n1');
    expect(m.kind, 'booking_confirmed');
    expect(m.title, 'Booking Confirmed');
    expect(m.body, 'Your session is confirmed.');
    expect(m.bookingId, 'b-42');
    expect(m.readAt, isNull);
    expect(m.isUnread, isTrue);
    expect(m.emailSentAt, isNotNull);
    expect(m.createdAt, isNotNull);
  });

  test('NotificationModel treats missing booking as null', () {
    final m = NotificationModel.fromJson({
      'id': 'n2',
      'kind': 'booking_received',
      'title': 'New booking',
      'body': 'Hello',
      'created_at': '2026-07-19T12:00:00Z',
    });
    expect(m.bookingId, isNull);
    expect(m.audience, 'personal');
    expect(NotificationModel.isOrgFacingKind(m.kind), isTrue);
  });

  test('NotificationModel parses audience and conversation', () {
    final m = NotificationModel.fromJson({
      'id': 'n3',
      'kind': 'message_received',
      'audience': 'organization',
      'title': 'New message',
      'body': 'Hi',
      'conversation': 'conv-9',
      'organization': 'org-1',
      'created_at': '2026-07-19T12:00:00Z',
    });
    expect(m.audience, 'organization');
    expect(m.conversationId, 'conv-9');
    expect(m.organizationId, 'org-1');
  });

  test('isOrgFacingKind covers business inbox kinds', () {
    expect(NotificationModel.isOrgFacingKind('booking_received'), isTrue);
    expect(NotificationModel.isOrgFacingKind('reschedule_proposed'), isTrue);
    expect(NotificationModel.isOrgFacingKind('booking_confirmed'), isFalse);
  });
}
