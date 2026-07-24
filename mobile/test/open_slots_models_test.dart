import 'package:flutter_test/flutter_test.dart';
import 'package:vaxiil_mobile/features/bookings/data/booking_models.dart';
import 'package:vaxiil_mobile/features/bookings/presentation/utils/booking_schedule_utils.dart';
import 'package:vaxiil_mobile/features/services/data/service_catalog_models.dart';

void main() {
  group('OpenSlotsResult', () {
    test('parses slots and duration', () {
      final result = OpenSlotsResult.fromJson({
        'date': '2026-04-06',
        'duration_minutes': 45,
        'slots': [
          {
            'start_time': '2026-04-06T09:00:00Z',
            'end_time': '2026-04-06T09:45:00Z',
          },
          {
            'start_time': '2026-04-06T10:00:00Z',
            'end_time': '2026-04-06T10:45:00Z',
          },
        ],
      });
      expect(result.date, '2026-04-06');
      expect(result.durationMinutes, 45);
      expect(result.slots.length, 2);
      expect(result.slots.first.startTime.toUtc().hour, 9);
      expect(result.slots.first.endTime.toUtc().minute, 45);
    });

    test('empty slots when omitted', () {
      final result = OpenSlotsResult.fromJson({
        'date': '2026-04-06',
        'duration_minutes': '60',
      });
      expect(result.durationMinutes, 60);
      expect(result.slots, isEmpty);
    });
  });

  group('bookingDurationMinutes', () {
    test('prefers variant duration', () {
      final booking = BookingDetailModel.fromJson({
        'id': 'b1',
        'service': 's1',
        'organization': 'o1',
        'status': {'value': 'Q', 'title': 'Requested', 'css': 'info'},
        'total_price': '10',
        'service_variant': {
          'id': 'v1',
          'name': 'Standard',
          'duration_minutes': 90,
          'price': '50',
        },
        'time_slots': [
          {
            'id': 't1',
            'start_time': '2026-04-06T09:00:00Z',
            'end_time': '2026-04-06T10:00:00Z',
          },
        ],
      });
      expect(bookingDurationMinutes(booking), 90);
    });

    test('falls back to slot length then 60', () {
      final fromSlot = BookingDetailModel.fromJson({
        'id': 'b1',
        'service': 's1',
        'organization': 'o1',
        'status': {'value': 'Q', 'title': 'Requested', 'css': 'info'},
        'total_price': '10',
        'time_slots': [
          {
            'id': 't1',
            'start_time': '2026-04-06T09:00:00Z',
            'end_time': '2026-04-06T10:30:00Z',
          },
        ],
      });
      expect(bookingDurationMinutes(fromSlot), 90);

      final fallback = BookingDetailModel.fromJson({
        'id': 'b2',
        'service': 's1',
        'organization': 'o1',
        'status': {'value': 'Q', 'title': 'Requested', 'css': 'info'},
        'total_price': '10',
        'time_slots': [],
      });
      expect(bookingDurationMinutes(fallback), 60);
    });
  });
}
