import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:vaxiil_mobile/features/bookings/data/booking_models.dart';
import 'package:vaxiil_mobile/features/bookings/data/bookings_repository.dart';

void main() {
  test('BookingTimeSlotModel parses home location type', () {
    final slot = BookingTimeSlotModel.fromJson({
      'id': 'ts-home',
      'start_time': '2026-04-10T14:00:00Z',
      'end_time': '2026-04-10T15:00:00Z',
      'location_type': {
        'value': 'H',
        'title': 'At Client Home',
        'css': 'default',
      },
    });
    expect(slot.locationType?.value, 'H');
    expect(slot.locationType?.title, 'At Client Home');
  });

  test('booking money formatter uses two fraction digits', () {
    final formatted =
        NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 2).format(75.5);
    expect(formatted, contains('75.50'));
  });

  test('BookingDetailModel parses platform fee fields', () {
    final json = <String, dynamic>{
      'id': 'b1',
      'service': 's1',
      'organization': 'o1',
      'status': {'value': 'Q', 'title': 'Requested', 'css': 'info'},
      'base_price': '100.00',
      'platform_fee_rate': '1.00',
      'platform_fee_amount': '1.00',
      'platform_fee_payer': {
        'value': 'C',
        'title': 'Client',
        'css': 'info',
      },
      'platform_fee_source': {
        'value': 'G',
        'title': 'Global',
        'css': 'default',
      },
      'total_price': '101.00',
      'accepted_currency': {
        'currency': {'code': 'USD'},
      },
      'time_slots': [],
    };

    final m = BookingDetailModel.fromJson(json);
    expect(m.basePrice, '100.00');
    expect(m.platformFeeAmount, '1.00');
    expect(m.platformFeePayer?.value, 'C');
    expect(m.showsClientFeeBreakdown, isTrue);
    expect(m.totalPrice, '101.00');
    expect(m.isPaid, isFalse);
    expect(m.pendingReschedule, isNull);
  });

  test('BookingDetailModel parses is_paid and pending_reschedule', () {
    final json = <String, dynamic>{
      'id': 'b-paid',
      'service': 's1',
      'organization': 'o1',
      'status': {'value': 'R', 'title': 'Rescheduled', 'css': 'warning'},
      'total_price': '50.00',
      'is_paid': true,
      'accepted_currency': {
        'currency': {'code': 'USD'},
      },
      'time_slots': [],
      'pending_reschedule': {
        'id': 'pr1',
        'proposed_by': {
          'value': 'B',
          'title': 'Business',
          'css': 'primary',
        },
        'status': {'value': 'P', 'title': 'Pending', 'css': 'warning'},
        'time_slots': [
          {
            'start_time': '2030-06-01T10:00:00Z',
            'end_time': '2030-06-01T11:00:00Z',
            'location_type': 'O',
          },
        ],
        'reason': 'Staff conflict',
        'decided_at': null,
        'created_at': '2026-07-01T12:00:00Z',
      },
    };

    final m = BookingDetailModel.fromJson(json);
    expect(m.isPaid, isTrue);
    expect(m.pendingReschedule?.id, 'pr1');
    expect(m.pendingReschedule?.proposedBy?.value, 'B');
    expect(m.pendingReschedule?.isProposedByBusiness, isTrue);
    expect(m.pendingReschedule?.status?.value, 'P');
    expect(m.pendingReschedule?.timeSlots, hasLength(1));
    expect(m.pendingReschedule?.reason, 'Staff conflict');
    expect(m.pendingReschedule?.createdAt?.toUtc().day, 1);
  });

  test('BookingDetailModel hides fee breakdown when business pays', () {
    final json = <String, dynamic>{
      'id': 'b2',
      'service': 's1',
      'organization': 'o1',
      'status': {'value': 'Q', 'title': 'Requested', 'css': 'info'},
      'base_price': '100.00',
      'platform_fee_amount': '1.00',
      'platform_fee_payer': {
        'value': 'B',
        'title': 'Business',
        'css': 'warning',
      },
      'total_price': '100.00',
      'accepted_currency': {
        'currency': {'code': 'USD'},
      },
      'time_slots': [],
    };

    final m = BookingDetailModel.fromJson(json);
    expect(m.showsClientFeeBreakdown, isFalse);
  });

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
      'service': {
        'id': 's9',
        'name': 'Deep Tissue Massage',
        'category': {
          'id': 'c1',
          'name': 'Massage',
          'icon': 'sparkles',
        },
      },
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
    expect(m.serviceCategory?.name, 'Massage');
    expect(m.serviceCategory?.icon, 'sparkles');
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

  test('BookingDetailModel parses nested service, org, practitioner', () {
    final json = <String, dynamic>{
      'id': 'b1',
      'service': {
        'id': 's1',
        'name': 'Forest Immersion',
        'category': {
          'id': 'c2',
          'name': 'Nature',
          'icon': 'sun',
        },
      },
      'organization': {
        'id': 'o1',
        'name': 'The Zen Clearing Studio',
        'logo': 'https://example.com/logo.png',
      },
      'practitioner': {
        'id': 'u1',
        'first_name': 'Elena',
        'last_name': 'Thorne',
        'avatar_url': 'https://example.com/a.png',
      },
      'practitioner_alias': 'Dr. Backup',
      'status': {'value': 'F', 'title': 'Confirmed', 'css': 'success'},
      'total_price': '42.50',
      'accepted_currency': {
        'id': 'cac1',
        'currency': {'code': 'USD', 'symbol': r'$'},
      },
      'time_slots': [],
    };

    final m = BookingDetailModel.fromJson(json);
    expect(m.serviceId, 's1');
    expect(m.serviceName, 'Forest Immersion');
    expect(m.serviceCategory?.name, 'Nature');
    expect(m.organizationName, 'The Zen Clearing Studio');
    expect(m.organizationLogoUrl, 'https://example.com/logo.png');
    expect(m.practitioner?.displayName, 'Elena Thorne');
    expect(m.practitionerDisplayLine, 'Elena Thorne');
    expect(m.displayServiceTitle(null), 'Forest Immersion');
  });

  test('BookingListItemModel maps organization id from nested map', () {
    final json = <String, dynamic>{
      'id': 'b3',
      'service': {
        'id': 's1',
        'name': 'X',
        'category': {'id': 'c', 'name': 'C', 'icon': ''},
      },
      'organization': {'id': 'org-uuid', 'name': 'O'},
      'status': {'value': 'F', 'title': 'Confirmed', 'css': 'success'},
      'total_price': '10',
      'accepted_currency': {
        'currency': {'code': 'USD', 'symbol': r'$'},
      },
      'time_slots': [],
    };
    final m = BookingListItemModel.fromJson(json);
    expect(m.organizationId, 'org-uuid');
  });

  test('PaymentLinkResult parses collect response', () {
    final r = PaymentLinkResult.fromJson(<String, dynamic>{
      'merchant_reference': 'bk_1_abc',
      'transaction_id': 'txn-uuid',
      'amount_charged': '50.00',
      'wallet_applied': '0',
      'fully_paid': false,
      'status': 'pending',
      'message': 'Approve on phone',
    });
    expect(r.url, isNull);
    expect(r.merchantReference, 'bk_1_abc');
    expect(r.transactionId, 'txn-uuid');
    expect(r.status, 'pending');
    expect(r.message, 'Approve on phone');
  });

  test('BookingDetailModel parses client and payment_summary', () {
    final json = <String, dynamic>{
      'id': 'b1',
      'service': {
        'id': 's1',
        'name': 'X',
        'category': {'id': 'c', 'name': 'C', 'icon': ''},
      },
      'organization': {'id': 'o1', 'name': 'Org'},
      'status': {'value': 'F', 'title': 'Confirmed', 'css': 'success'},
      'total_price': '10',
      'accepted_currency': {
        'currency': {'code': 'USD'}
      },
      'time_slots': [],
      'client': {
        'id': 'u9',
        'trust_alias': 'Willow',
        'age': 35,
        'sex': {'value': 'F', 'title': 'Female', 'css': 'danger'},
        'first_name': 'Ada',
        'last_name': 'Lovelace',
        'phone': '+15551234',
        'email': 'ada@example.com',
      },
      'payment_summary': {
        'net_captured': '75.00',
        'currency_code': 'USD',
        'inscription_fee_amount': '5.00',
        'amount_due': '80.00',
        'inscription_fee_note': 'One-time fee',
      },
      'inscription_fee_amount': '5.00',
      'internal_notes': 'VIP',
    };
    final m = BookingDetailModel.fromJson(json);
    expect(m.client?.email, 'ada@example.com');
    expect(m.client?.displayName, 'Ada Lovelace');
    expect(m.client?.phone, '+15551234');
    expect(m.client?.age, 35);
    expect(m.client?.sex?.value, 'F');
    expect(m.paymentSummary?.netCaptured, '75.00');
    expect(m.paymentSummary?.inscriptionFeeAmount, '5.00');
    expect(m.paymentSummary?.amountDue, '80.00');
    expect(m.effectiveInscriptionFeeAmount, '5.00');
    expect(m.amountDueForPayment, '80.00');
    expect(m.internalNotes, 'VIP');
  });

  test('BookingClientBrief falls back to trust alias then customer', () {
    final alias = BookingClientBrief.fromJson({
      'id': 'u1',
      'trust_alias': 'Quiet Cedar',
    });
    final anonymous = BookingClientBrief.fromJson({'id': 'u2'});

    expect(alias.displayName, 'Quiet Cedar');
    expect(anonymous.displayName, 'Customer');
  });

  test('BookingDetailModel parses venue and special_requests', () {
    final json = <String, dynamic>{
      'id': 'b1',
      'service': {
        'id': 's1',
        'name': 'X',
        'category': {'id': 'c', 'name': 'C', 'icon': ''},
      },
      'organization': {'id': 'o1', 'name': 'Org'},
      'status': {'value': 'F', 'title': 'Confirmed', 'css': 'success'},
      'total_price': '10',
      'special_requests': 'Quiet room please',
      'accepted_currency': {
        'currency': {'code': 'USD'}
      },
      'time_slots': [
        {
          'id': 'ts1',
          'start_time': '2030-01-15T15:30:00Z',
          'end_time': '2030-01-15T16:30:00Z',
          'location_type': {'value': 'O', 'title': 'Office', 'css': 'default'},
          'address': '12 Oak St',
          'room_details': 'Suite B',
          'virtual_meeting_link': '',
          'notes': 'Ring doorbell',
        },
      ],
      'client': {
        'id': 'u9',
        'trust_alias': 'Willow',
        'age': 35,
        'sex': {'value': 'F', 'title': 'Female', 'css': 'danger'},
      },
    };
    final m = BookingDetailModel.fromJson(json);
    expect(m.specialRequests, 'Quiet room please');
    expect(m.timeSlots.first.address, '12 Oak St');
    expect(m.timeSlots.first.roomDetails, 'Suite B');
    expect(m.timeSlots.first.notes, 'Ring doorbell');
    expect(m.client?.displayName, 'Willow');
    expect(m.client?.age, 35);
    expect(m.client?.sex?.title, 'Female');
  });

  test('sortedUpcomingBookingList orders by earliest slot', () {
    final a = BookingListItemModel.fromJson(<String, dynamic>{
      'id': 'a',
      'service': {
        'id': 's',
        'name': 'S',
        'category': {'id': 'c', 'name': 'C', 'icon': ''}
      },
      'organization': 'o',
      'status': {'value': 'F', 'title': 'Confirmed', 'css': 'success'},
      'total_price': '1',
      'accepted_currency': {
        'currency': {'code': 'USD'}
      },
      'time_slots': [
        {
          'start_time': '2030-06-02T10:00:00Z',
          'end_time': '2030-06-02T11:00:00Z',
          'location_type': {'value': 'O', 'title': '', 'css': 'default'},
        },
      ],
    });
    final b = BookingListItemModel.fromJson(<String, dynamic>{
      'id': 'b',
      'service': {
        'id': 's',
        'name': 'S',
        'category': {'id': 'c', 'name': 'C', 'icon': ''}
      },
      'organization': 'o',
      'status': {'value': 'F', 'title': 'Confirmed', 'css': 'success'},
      'total_price': '1',
      'accepted_currency': {
        'currency': {'code': 'USD'}
      },
      'time_slots': [
        {
          'start_time': '2030-06-01T10:00:00Z',
          'end_time': '2030-06-01T11:00:00Z',
          'location_type': {'value': 'O', 'title': '', 'css': 'default'},
        },
      ],
    });
    final out = sortedUpcomingBookingList([a, b]);
    expect(out.first.id, 'b');
    expect(out.last.id, 'a');
  });
}
