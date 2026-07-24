import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaxiil_mobile/features/bookings/presentation/utils/booking_schedule_utils.dart';

void main() {
  group('parseApiTimeOfDay', () {
    test('parses HH:mm and HH:mm:ss', () {
      expect(parseApiTimeOfDay('09:30'), const TimeOfDay(hour: 9, minute: 30));
      expect(parseApiTimeOfDay('17:00:00'), const TimeOfDay(hour: 17, minute: 0));
      expect(parseApiTimeOfDay(null), isNull);
      expect(parseApiTimeOfDay(''), isNull);
    });
  });

  group('generateTimeSlots', () {
    test('emits half-hour steps inclusive of end', () {
      final slots = generateTimeSlots(
        start: const TimeOfDay(hour: 9, minute: 0),
        end: const TimeOfDay(hour: 10, minute: 0),
        intervalMinutes: 30,
      );
      expect(slots.length, 3);
      expect(slots.first, const TimeOfDay(hour: 9, minute: 0));
      expect(slots.last, const TimeOfDay(hour: 10, minute: 0));
    });
  });

  group('combineDateAndTime', () {
    test('merges local date and time', () {
      final d = DateTime(2026, 4, 6);
      const t = TimeOfDay(hour: 14, minute: 30);
      final c = combineDateAndTime(d, t);
      expect(c.year, 2026);
      expect(c.month, 4);
      expect(c.day, 6);
      expect(c.hour, 14);
      expect(c.minute, 30);
    });
  });

  group('monthGridDays', () {
    test('April 2026 starts Tuesday; grid includes March padding', () {
      final focused = DateTime(2026, 4, 1);
      final grid = monthGridDays(focused);
      expect(grid.first, DateTime(2026, 3, 30)); // Monday 30 March
      expect(grid.length % 7, 0);
      expect(isInMonth(grid.first, focused), isFalse);
      expect(isInMonth(DateTime(2026, 4, 1), focused), isTrue);
    });
  });

  group('slotTooSoon', () {
    test('true when slot is before earliest', () {
      final day = DateTime(2026, 4, 6);
      const slot = TimeOfDay(hour: 9, minute: 0);
      final earliest = DateTime(2026, 4, 6, 10, 0);
      expect(
        slotTooSoon(day: day, slot: slot, earliest: earliest),
        isTrue,
      );
    });
  });

  group('formatApiDate', () {
    test('pads month and day', () {
      expect(formatApiDate(DateTime(2026, 4, 6)), '2026-04-06');
      expect(formatApiDate(DateTime(2026, 12, 31, 23, 59)), '2026-12-31');
    });
  });

  group('sameOpenSlotStart', () {
    test('compares UTC instants', () {
      final a = DateTime.parse('2026-04-06T14:00:00Z');
      final b = DateTime.parse('2026-04-06T14:00:00.000Z');
      final c = DateTime.parse('2026-04-06T15:00:00Z');
      expect(sameOpenSlotStart(a, b), isTrue);
      expect(sameOpenSlotStart(a, c), isFalse);
      expect(sameOpenSlotStart(a, null), isFalse);
    });
  });
}
