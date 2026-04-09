import 'package:flutter/material.dart';
import 'package:vaxiil_mobile/features/services/data/service_catalog_models.dart';

/// Stitch “Booking & Scheduling” accent for selected date / time chips.
const Color kBookingSelectionAccent = Color(0xFFF57C00);

/// Parses API time strings such as `09:00`, `9:00`, or `09:00:00`.
TimeOfDay? parseApiTimeOfDay(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }
  final parts = raw.trim().split(':');
  if (parts.length < 2) {
    return null;
  }
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) {
    return null;
  }
  return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
}

/// Half-hour slots from [start] through [end] inclusive (end minute included).
List<TimeOfDay> generateTimeSlots({
  required TimeOfDay start,
  required TimeOfDay end,
  int intervalMinutes = 30,
}) {
  final out = <TimeOfDay>[];
  var cur = start.hour * 60 + start.minute;
  final endMin = end.hour * 60 + end.minute;
  if (cur > endMin) {
    return out;
  }
  while (cur <= endMin) {
    out.add(TimeOfDay(hour: cur ~/ 60, minute: cur % 60));
    cur += intervalMinutes;
  }
  return out;
}

/// Slots for a service using API window or sensible defaults (09:00–17:00).
List<TimeOfDay> timeSlotsForService(ServiceDetailModel s) {
  final start = parseApiTimeOfDay(s.availableStartTime) ??
      const TimeOfDay(hour: 9, minute: 0);
  final end = parseApiTimeOfDay(s.availableEndTime) ??
      const TimeOfDay(hour: 17, minute: 0);
  return generateTimeSlots(start: start, end: end, intervalMinutes: 30);
}

DateTime combineDateAndTime(DateTime date, TimeOfDay time) {
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

bool isSameCalendarDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// First day shown in a Monday-first month grid (may be in the previous month).
DateTime firstVisibleDay(DateTime month) {
  final first = DateTime(month.year, month.month, 1);
  final leading = (first.weekday - DateTime.monday + 7) % 7;
  return first.subtract(Duration(days: leading));
}

/// Number of days in [month].
int daysInMonth(DateTime month) {
  return DateTime(month.year, month.month + 1, 0).day;
}

/// Calendar cells for [focusedMonth]: only [month] days are “in month”; others
/// are padding days (show disabled / grey).
List<DateTime> monthGridDays(DateTime focusedMonth) {
  final firstVisible = firstVisibleDay(focusedMonth);
  final dim = daysInMonth(focusedMonth);
  final first = DateTime(focusedMonth.year, focusedMonth.month, 1);
  final leading = first.difference(firstVisible).inDays;
  final total = leading + dim;
  final rows = (total / 7).ceil();
  final cells = rows * 7;
  return List.generate(cells, (i) {
    return firstVisible.add(Duration(days: i));
  });
}

bool isInMonth(DateTime day, DateTime month) {
  return day.year == month.year && day.month == month.month;
}

DateTime lastBookableDate(ServiceDetailModel s, DateTime now) {
  final adv = s.bookingAdvanceDays;
  if (adv == null || adv <= 0) {
    return DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 365));
  }
  return DateTime(now.year, now.month, now.day).add(Duration(days: adv));
}

/// Earliest instant the user may book (respects [minimumBookingHours]).
DateTime earliestBookingInstant(ServiceDetailModel s, DateTime now) {
  final h = s.minimumBookingHours;
  if (h == null || h <= 0) {
    return now;
  }
  return now.add(Duration(hours: h));
}

/// True when the slot is strictly before [earliest] (cannot book yet).
bool slotTooSoon({
  required DateTime day,
  required TimeOfDay slot,
  required DateTime earliest,
}) {
  final t = combineDateAndTime(day, slot);
  return t.isBefore(earliest);
}
