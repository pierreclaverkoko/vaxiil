import 'package:vaxiil_mobile/shared/models/choice_enum_data.dart';

class BookingTimeSlotModel {
  const BookingTimeSlotModel({
    required this.id,
    this.startTime,
    this.endTime,
    this.locationType,
    this.address,
    this.roomDetails,
    this.virtualMeetingLink,
    this.notes,
  });

  factory BookingTimeSlotModel.fromJson(Map<String, dynamic> json) {
    return BookingTimeSlotModel(
      id: json['id']?.toString() ?? '',
      startTime: json['start_time'] != null
          ? DateTime.tryParse(json['start_time'] as String)
          : null,
      endTime: json['end_time'] != null
          ? DateTime.tryParse(json['end_time'] as String)
          : null,
      locationType: ChoiceEnumData.parse(json['location_type']),
      address: json['address'] as String?,
      roomDetails: json['room_details'] as String?,
      virtualMeetingLink: json['virtual_meeting_link'] as String?,
      notes: json['notes'] as String?,
    );
  }

  final String id;
  final DateTime? startTime;
  final DateTime? endTime;
  final ChoiceEnumData? locationType;
  final String? address;
  final String? roomDetails;
  final String? virtualMeetingLink;
  final String? notes;
}

class BookingVariantBriefModel {
  const BookingVariantBriefModel({
    required this.id,
    required this.name,
    required this.durationMinutes,
    required this.price,
  });

  factory BookingVariantBriefModel.fromJson(Map<String, dynamic> json) {
    return BookingVariantBriefModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      durationMinutes: json['duration_minutes'] as int? ?? 0,
      price: json['price']?.toString() ?? '0',
    );
  }

  final String id;
  final String name;
  final int durationMinutes;
  final String price;
}

class BookingDetailModel {
  const BookingDetailModel({
    required this.id,
    required this.serviceId,
    required this.organizationId,
    required this.status,
    required this.totalPrice,
    this.currencyCode,
    this.specialRequests,
    this.cancellationReason,
    this.serviceVariant,
    this.timeSlots = const [],
    this.createdAt,
  });

  factory BookingDetailModel.fromJson(Map<String, dynamic> json) {
    final ac = json['accepted_currency'];
    String? code;
    if (ac is Map<String, dynamic>) {
      final c = ac['currency'];
      if (c is Map<String, dynamic>) {
        code = c['code'] as String?;
      }
    }
    BookingVariantBriefModel? variant;
    final sv = json['service_variant'];
    if (sv is Map<String, dynamic>) {
      variant = BookingVariantBriefModel.fromJson(sv);
    }
    final slots = <BookingTimeSlotModel>[];
    final rawSlots = json['time_slots'];
    if (rawSlots is List<dynamic>) {
      for (final e in rawSlots) {
        if (e is Map<String, dynamic>) {
          slots.add(BookingTimeSlotModel.fromJson(e));
        }
      }
    }
    return BookingDetailModel(
      id: json['id']?.toString() ?? '',
      serviceId: json['service']?.toString() ?? '',
      organizationId: json['organization']?.toString() ?? '',
      status: ChoiceEnumData.parse(json['status']),
      totalPrice: json['total_price']?.toString() ?? '0',
      currencyCode: code ?? 'USD',
      specialRequests: json['special_requests'] as String?,
      cancellationReason: json['cancellation_reason'] as String?,
      serviceVariant: variant,
      timeSlots: slots,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  final String id;
  final String serviceId;
  final String organizationId;
  final ChoiceEnumData? status;
  final String totalPrice;
  final String? currencyCode;
  final String? specialRequests;
  final String? cancellationReason;
  final BookingVariantBriefModel? serviceVariant;
  final List<BookingTimeSlotModel> timeSlots;
  final DateTime? createdAt;
}

class BookingListItemModel {
  const BookingListItemModel({
    required this.id,
    required this.serviceId,
    required this.organizationId,
    required this.status,
    required this.totalPrice,
    this.currencyCode,
    this.createdAt,
    this.serviceName,
    this.practitionerAlias,
    this.serviceVariant,
    this.timeSlots = const [],
  });

  factory BookingListItemModel.fromJson(Map<String, dynamic> json) {
    final ac = json['accepted_currency'];
    String? code;
    if (ac is Map<String, dynamic>) {
      final c = ac['currency'];
      if (c is Map<String, dynamic>) {
        code = c['code'] as String?;
      }
    }
    final String serviceId;
    final String? serviceName;
    final rawService = json['service'];
    if (rawService is Map<String, dynamic>) {
      serviceId = rawService['id']?.toString() ?? '';
      serviceName = rawService['name'] as String?;
    } else {
      serviceId = rawService?.toString() ?? '';
      serviceName = null;
    }
    BookingVariantBriefModel? variant;
    final sv = json['service_variant'];
    if (sv is Map<String, dynamic>) {
      variant = BookingVariantBriefModel.fromJson(sv);
    }
    final slots = <BookingTimeSlotModel>[];
    final rawSlots = json['time_slots'];
    if (rawSlots is List<dynamic>) {
      for (final e in rawSlots) {
        if (e is Map<String, dynamic>) {
          slots.add(BookingTimeSlotModel.fromJson(e));
        }
      }
    }
    return BookingListItemModel(
      id: json['id']?.toString() ?? '',
      serviceId: serviceId,
      organizationId: json['organization']?.toString() ?? '',
      status: ChoiceEnumData.parse(json['status']),
      totalPrice: json['total_price']?.toString() ?? '0',
      currencyCode: code ?? 'USD',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      serviceName: serviceName,
      practitionerAlias: json['practitioner_alias'] as String?,
      serviceVariant: variant,
      timeSlots: slots,
    );
  }

  final String id;
  final String serviceId;
  final String organizationId;
  final ChoiceEnumData? status;
  final String totalPrice;
  final String? currencyCode;
  final DateTime? createdAt;
  final String? serviceName;
  final String? practitionerAlias;
  final BookingVariantBriefModel? serviceVariant;
  final List<BookingTimeSlotModel> timeSlots;
}

/// List / hub helpers for upcoming vs past and sorting.
extension BookingListItemModelX on BookingListItemModel {
  DateTime? get earliestSlotStart {
    if (timeSlots.isEmpty) return null;
    DateTime? best;
    for (final s in timeSlots) {
      final t = s.startTime;
      if (t == null) continue;
      if (best == null || t.isBefore(best)) best = t;
    }
    return best;
  }

  /// Past vs upcoming: terminal statuses, or session start in the past.
  bool get isPastBooking {
    final v = status?.value ?? '';
    if (v == 'P') return false;
    if (v == 'M' || v == 'X' || v == 'N') return true;
    final start = earliestSlotStart;
    final now = DateTime.now();
    if (start != null && !start.isAfter(now)) return true;
    return false;
  }

  String get displayTitle {
    final n = serviceName?.trim();
    if (n != null && n.isNotEmpty) return n;
    final vn = serviceVariant?.name.trim();
    if (vn != null && vn.isNotEmpty) return vn;
    return 'Booking';
  }

  String? get displayProviderSubtitle {
    final a = practitionerAlias?.trim();
    if (a != null && a.isNotEmpty) return a;
    return null;
  }
}
