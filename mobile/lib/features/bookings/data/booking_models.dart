import 'package:vaxiil_mobile/features/services/data/service_catalog_models.dart';
import 'package:vaxiil_mobile/shared/models/choice_enum_data.dart';

ServiceCategoryBrief? _serviceCategoryFromNestedService(dynamic rawService) {
  if (rawService is! Map<String, dynamic>) return null;
  final c = rawService['category'];
  if (c is! Map<String, dynamic>) return null;
  return ServiceCategoryBrief.fromJson({
    'id': c['id']?.toString() ?? '',
    'name': c['name'] as String? ?? '',
    'icon': c['icon'] as String? ?? '',
  });
}

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

class PractitionerBriefModel {
  const PractitionerBriefModel({
    required this.id,
    this.firstName,
    this.lastName,
    this.avatarUrl,
  });

  factory PractitionerBriefModel.fromJson(Map<String, dynamic> json) {
    return PractitionerBriefModel(
      id: json['id']?.toString() ?? '',
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  final String id;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;

  String get displayName {
    final fn = firstName?.trim() ?? '';
    final ln = lastName?.trim() ?? '';
    return '$fn $ln'.trim();
  }
}

class BookingClientBrief {
  const BookingClientBrief({
    required this.id,
    this.trustAlias,
    this.age,
    this.sex,
    this.firstName,
    this.lastName,
    this.phone,
    this.email,
  });

  factory BookingClientBrief.fromJson(Map<String, dynamic> json) {
    return BookingClientBrief(
      id: json['id']?.toString() ?? '',
      trustAlias: json['trust_alias'] as String?,
      age: json['age'] is int
          ? json['age'] as int
          : int.tryParse('${json['age']}'),
      sex: ChoiceEnumData.parse(json['sex']),
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
    );
  }

  final String id;
  final String? trustAlias;
  final int? age;
  final ChoiceEnumData? sex;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? email;

  String get displayName {
    final n = '${firstName?.trim() ?? ''} ${lastName?.trim() ?? ''}'.trim();
    if (n.isNotEmpty) return n;
    final alias = trustAlias?.trim() ?? '';
    return alias.isNotEmpty ? alias : 'Customer';
  }
}

class BookingPaymentSummaryBrief {
  const BookingPaymentSummaryBrief({
    required this.netCaptured,
    this.currencyCode,
    this.inscriptionFeeAmount = '0',
    this.amountDue,
    this.inscriptionFeeNote,
  });

  factory BookingPaymentSummaryBrief.fromJson(Map<String, dynamic> json) {
    return BookingPaymentSummaryBrief(
      netCaptured: json['net_captured']?.toString() ?? '0',
      currencyCode: json['currency_code'] as String?,
      inscriptionFeeAmount: json['inscription_fee_amount']?.toString() ?? '0',
      amountDue: json['amount_due']?.toString(),
      inscriptionFeeNote: json['inscription_fee_note'] as String?,
    );
  }

  final String netCaptured;
  final String? currencyCode;
  final String inscriptionFeeAmount;
  final String? amountDue;
  final String? inscriptionFeeNote;
}

/// Pending counterparty decision from API `pending_reschedule`.
class PendingRescheduleModel {
  const PendingRescheduleModel({
    required this.id,
    this.proposedBy,
    this.status,
    this.timeSlots = const [],
    this.reason,
    this.decidedAt,
    this.createdAt,
  });

  factory PendingRescheduleModel.fromJson(Map<String, dynamic> json) {
    final rawSlots = json['time_slots'];
    final slots = <dynamic>[];
    if (rawSlots is List<dynamic>) {
      slots.addAll(rawSlots);
    }
    return PendingRescheduleModel(
      id: json['id']?.toString() ?? '',
      proposedBy: ChoiceEnumData.parse(json['proposed_by']),
      status: ChoiceEnumData.parse(json['status']),
      timeSlots: slots,
      reason: json['reason'] as String?,
      decidedAt: json['decided_at'] != null
          ? DateTime.tryParse(json['decided_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  final String id;
  final ChoiceEnumData? proposedBy;
  final ChoiceEnumData? status;

  /// Proposed slots as returned by the API (list of maps).
  final List<dynamic> timeSlots;
  final String? reason;
  final DateTime? decidedAt;
  final DateTime? createdAt;

  bool get isProposedByClient => proposedBy?.value == 'C';
  bool get isProposedByBusiness => proposedBy?.value == 'B';
}

class BookingDetailModel {
  const BookingDetailModel({
    required this.id,
    required this.serviceId,
    required this.organizationId,
    required this.status,
    required this.totalPrice,
    this.basePrice,
    this.platformFeeRate,
    this.platformFeeAmount,
    this.platformFeePayer,
    this.platformFeeSource,
    this.currencyCode,
    this.specialRequests,
    this.cancellationReason,
    this.serviceVariant,
    this.timeSlots = const [],
    this.createdAt,
    this.serviceName,
    this.organizationName,
    this.organizationLogoUrl,
    this.practitioner,
    this.practitionerAlias,
    this.serviceCategory,
    this.client,
    this.internalNotes,
    this.paymentSummary,
    this.isPaid = false,
    this.pendingReschedule,
    this.inscriptionFeeAmount,
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
    final String serviceId;
    String? serviceName;
    ServiceCategoryBrief? serviceCategory;
    final rawService = json['service'];
    if (rawService is Map<String, dynamic>) {
      serviceId = rawService['id']?.toString() ?? '';
      serviceName = rawService['name'] as String?;
      serviceCategory = _serviceCategoryFromNestedService(rawService);
    } else {
      serviceId = rawService?.toString() ?? '';
    }
    final String organizationId;
    String? organizationName;
    String? organizationLogoUrl;
    final rawOrg = json['organization'];
    if (rawOrg is Map<String, dynamic>) {
      organizationId = rawOrg['id']?.toString() ?? '';
      organizationName = rawOrg['name'] as String?;
      organizationLogoUrl = rawOrg['logo'] as String?;
    } else {
      organizationId = rawOrg?.toString() ?? '';
    }
    PractitionerBriefModel? practitioner;
    final rawP = json['practitioner'];
    if (rawP is Map<String, dynamic>) {
      practitioner = PractitionerBriefModel.fromJson(rawP);
    }
    BookingClientBrief? client;
    final rawClient = json['client'];
    if (rawClient is Map<String, dynamic>) {
      client = BookingClientBrief.fromJson(rawClient);
    }
    BookingPaymentSummaryBrief? paymentSummary;
    final rawPay = json['payment_summary'];
    if (rawPay is Map<String, dynamic>) {
      paymentSummary = BookingPaymentSummaryBrief.fromJson(rawPay);
    }
    PendingRescheduleModel? pendingReschedule;
    final rawPending = json['pending_reschedule'];
    if (rawPending is Map<String, dynamic>) {
      pendingReschedule = PendingRescheduleModel.fromJson(rawPending);
    }
    return BookingDetailModel(
      id: json['id']?.toString() ?? '',
      serviceId: serviceId,
      organizationId: organizationId,
      status: ChoiceEnumData.parse(json['status']),
      totalPrice: json['total_price']?.toString() ?? '0',
      basePrice: json['base_price']?.toString(),
      platformFeeRate: json['platform_fee_rate']?.toString(),
      platformFeeAmount: json['platform_fee_amount']?.toString(),
      platformFeePayer: ChoiceEnumData.parse(json['platform_fee_payer']),
      platformFeeSource: ChoiceEnumData.parse(json['platform_fee_source']),
      currencyCode: code ?? 'USD',
      specialRequests: json['special_requests'] as String?,
      cancellationReason: json['cancellation_reason'] as String?,
      serviceVariant: variant,
      timeSlots: slots,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      serviceName: serviceName,
      organizationName: organizationName,
      organizationLogoUrl: organizationLogoUrl,
      practitioner: practitioner,
      practitionerAlias: json['practitioner_alias'] as String?,
      serviceCategory: serviceCategory,
      client: client,
      internalNotes: json['internal_notes'] as String?,
      paymentSummary: paymentSummary,
      isPaid: json['is_paid'] == true,
      pendingReschedule: pendingReschedule,
      inscriptionFeeAmount: json['inscription_fee_amount']?.toString(),
    );
  }

  final String id;
  final String serviceId;
  final String organizationId;
  final ChoiceEnumData? status;
  final String totalPrice;
  final String? basePrice;
  final String? platformFeeRate;
  final String? platformFeeAmount;
  final ChoiceEnumData? platformFeePayer;
  final ChoiceEnumData? platformFeeSource;
  final String? currencyCode;
  final String? specialRequests;
  final String? cancellationReason;
  final BookingVariantBriefModel? serviceVariant;
  final List<BookingTimeSlotModel> timeSlots;
  final DateTime? createdAt;
  final String? serviceName;
  final String? organizationName;
  final String? organizationLogoUrl;
  final PractitionerBriefModel? practitioner;
  final String? practitionerAlias;

  /// Parent category from `service.category` (name + Heroicon key).
  final ServiceCategoryBrief? serviceCategory;

  final BookingClientBrief? client;
  final String? internalNotes;
  final BookingPaymentSummaryBrief? paymentSummary;
  final bool isPaid;
  final PendingRescheduleModel? pendingReschedule;
  final String? inscriptionFeeAmount;

  String get effectiveInscriptionFeeAmount {
    final fromSummary = paymentSummary?.inscriptionFeeAmount;
    if (fromSummary != null && fromSummary.isNotEmpty) {
      return fromSummary;
    }
    return inscriptionFeeAmount ?? '0';
  }

  String get amountDueForPayment {
    final due = paymentSummary?.amountDue;
    if (due != null && due.isNotEmpty) {
      return due;
    }
    final total = double.tryParse(totalPrice) ?? 0;
    final inscription = double.tryParse(effectiveInscriptionFeeAmount) ?? 0;
    return (total + inscription).toStringAsFixed(2);
  }

  bool get showsClientFeeBreakdown =>
      platformFeePayer?.value == 'C' &&
      basePrice != null &&
      platformFeeAmount != null;
}

/// Detail screen: upcoming vs past / display helpers.
extension BookingDetailModelX on BookingDetailModel {
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

  bool get isPastBooking {
    final v = status?.value ?? '';
    if (v == 'P') return false;
    if (v == 'M' || v == 'X' || v == 'N') return true;
    final start = earliestSlotStart;
    final now = DateTime.now();
    if (start != null && !start.isAfter(now)) return true;
    return false;
  }

  String displayServiceTitle(String? fallbackName) {
    final n = serviceName?.trim();
    if (n != null && n.isNotEmpty) return n;
    final f = fallbackName?.trim();
    if (f != null && f.isNotEmpty) return f;
    final vn = serviceVariant?.name.trim();
    if (vn != null && vn.isNotEmpty) return vn;
    return 'Service';
  }

  String? get practitionerDisplayLine {
    final p = practitioner;
    if (p != null && p.displayName.isNotEmpty) return p.displayName;
    final a = practitionerAlias?.trim();
    if (a != null && a.isNotEmpty) return a;
    return null;
  }

  /// Category from booking payload, or from loaded [service] detail.
  ServiceCategoryBrief? resolvedCategory(ServiceDetailModel? service) {
    if (serviceCategory != null) return serviceCategory;
    return service?.subCategory.category;
  }
}

class BookingListItemModel {
  const BookingListItemModel({
    required this.id,
    required this.serviceId,
    required this.organizationId,
    required this.status,
    required this.totalPrice,
    this.basePrice,
    this.platformFeeRate,
    this.platformFeeAmount,
    this.platformFeePayer,
    this.platformFeeSource,
    this.currencyCode,
    this.createdAt,
    this.serviceName,
    this.practitionerAlias,
    this.serviceVariant,
    this.timeSlots = const [],
    this.serviceCategory,
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
    ServiceCategoryBrief? serviceCategory;
    final rawService = json['service'];
    if (rawService is Map<String, dynamic>) {
      serviceId = rawService['id']?.toString() ?? '';
      serviceName = rawService['name'] as String?;
      serviceCategory = _serviceCategoryFromNestedService(rawService);
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
    String organizationId;
    final rawOrgList = json['organization'];
    if (rawOrgList is Map<String, dynamic>) {
      organizationId = rawOrgList['id']?.toString() ?? '';
    } else {
      organizationId = rawOrgList?.toString() ?? '';
    }
    return BookingListItemModel(
      id: json['id']?.toString() ?? '',
      serviceId: serviceId,
      organizationId: organizationId,
      status: ChoiceEnumData.parse(json['status']),
      totalPrice: json['total_price']?.toString() ?? '0',
      basePrice: json['base_price']?.toString(),
      platformFeeRate: json['platform_fee_rate']?.toString(),
      platformFeeAmount: json['platform_fee_amount']?.toString(),
      platformFeePayer: ChoiceEnumData.parse(json['platform_fee_payer']),
      platformFeeSource: ChoiceEnumData.parse(json['platform_fee_source']),
      currencyCode: code ?? 'USD',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      serviceName: serviceName,
      practitionerAlias: json['practitioner_alias'] as String?,
      serviceVariant: variant,
      timeSlots: slots,
      serviceCategory: serviceCategory,
    );
  }

  final String id;
  final String serviceId;
  final String organizationId;
  final ChoiceEnumData? status;
  final String totalPrice;
  final String? basePrice;
  final String? platformFeeRate;
  final String? platformFeeAmount;
  final ChoiceEnumData? platformFeePayer;
  final ChoiceEnumData? platformFeeSource;
  final String? currencyCode;
  final DateTime? createdAt;
  final String? serviceName;
  final String? practitionerAlias;
  final BookingVariantBriefModel? serviceVariant;
  final List<BookingTimeSlotModel> timeSlots;

  /// Parent category from `service.category` (name + Heroicon key).
  final ServiceCategoryBrief? serviceCategory;

  bool get showsClientFeeBreakdown =>
      platformFeePayer?.value == 'C' &&
      basePrice != null &&
      platformFeeAmount != null;
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

/// Sort helpers for booking list UIs (customer + business).
List<BookingListItemModel> sortedUpcomingBookingList(
  List<BookingListItemModel> items,
) {
  final u = items.where((b) => !b.isPastBooking).toList();
  int sk(BookingListItemModel b) {
    final t = b.earliestSlotStart;
    if (t == null) return 1 << 30;
    return t.millisecondsSinceEpoch;
  }

  u.sort((a, b) => sk(a).compareTo(sk(b)));
  return u;
}

List<BookingListItemModel> sortedPastBookingList(
  List<BookingListItemModel> items,
) {
  final p = items.where((b) => b.isPastBooking).toList();
  int sk(BookingListItemModel b) {
    final t = b.earliestSlotStart ?? b.createdAt;
    if (t == null) return 0;
    return -t.millisecondsSinceEpoch;
  }

  p.sort((a, b) => sk(a).compareTo(sk(b)));
  return p;
}
