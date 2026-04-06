import 'package:flutter_test/flutter_test.dart';
import 'package:vaxiil_mobile/features/bookings/data/booking_models.dart';

void main() {
  test('BookingDetailModel parses accepted_currency and time_slots', () {
    final json = <String, dynamic>{
      'id': 'b1',
      'service': 's1',
      'organization': 'o1',
      'status': {'value': 'Q', 'title': 'Requested', 'css': 'info'},
      'total_price': '42.50',
      'accepted_currency': {
        'id': 'cac1',
        'currency': {
          'code': 'USD',
          'symbol': r'$',
        },
      },
      'time_slots': [
        {
          'id': 'ts1',
          'start_time': '2026-04-10T14:00:00Z',
          'end_time': '2026-04-10T15:00:00Z',
          'location_type': {'value': 'O', 'title': 'Office', 'css': 'default'},
        },
      ],
      'service_variant': {
        'id': 'v1',
        'name': 'Standard',
        'duration_minutes': 60,
        'price': '42.50',
      },
    };

    final m = BookingDetailModel.fromJson(json);
    expect(m.id, 'b1');
    expect(m.currencyCode, 'USD');
    expect(m.timeSlots, hasLength(1));
    expect(m.timeSlots.first.startTime?.toUtc().hour, 14);
    expect(m.serviceVariant?.name, 'Standard');
  });

  test('BookingListItemModel parses nested service, slots, and past flag', () {
    final json = <String, dynamic>{
      'id': 'b2',
      'service': {'id': 's9', 'name': 'Deep Tissue Massage'},
      'organization': 'o1',
      'status': {'value': 'F', 'title': 'Confirmed', 'css': 'success'},
      'total_price': '99.00',
      'practitioner_alias': 'Dr. Elena Sterling',
      'accepted_currency': {
        'id': 'cac1',
        'currency': {'code': 'USD', 'symbol': r'$'},
      },
      'service_variant': {
        'id': 'v1',
        'name': '60 min',
        'duration_minutes': 60,
        'price': '99.00',
      },
      'time_slots': [
        {
          'id': 'ts1',
          'start_time': '2030-01-15T15:30:00Z',
          'end_time': '2030-01-15T16:30:00Z',
          'location_type': {'value': 'O', 'title': 'Office', 'css': 'default'},
        },
      ],
    };

    final m = BookingListItemModel.fromJson(json);
    expect(m.serviceId, 's9');
    expect(m.serviceName, 'Deep Tissue Massage');
    expect(m.displayTitle, 'Deep Tissue Massage');
    expect(m.isPastBooking, isFalse);

    final pastJson = Map<String, dynamic>.from(json);
    pastJson['status'] = {
      'value': 'M',
      'title': 'Completed',
      'css': 'secondary',
    };
    final past = BookingListItemModel.fromJson(pastJson);
    expect(past.isPastBooking, isTrue);
  });
}
