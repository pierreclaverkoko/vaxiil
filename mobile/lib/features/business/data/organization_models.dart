import 'package:vaxiil_mobile/shared/models/choice_enum_data.dart';

class OrganizationTypeOption {
  const OrganizationTypeOption({
    required this.id,
    required this.name,
    required this.displayName,
    this.description,
    this.icon,
  });

  final String id;
  final String name;
  final String displayName;
  final String? description;
  final String? icon;

  factory OrganizationTypeOption.fromJson(Map<String, dynamic> json) {
    return OrganizationTypeOption(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      description: json['description'] as String?,
      icon: json['icon'] as String?,
    );
  }
}

class OrganizationModel {
  const OrganizationModel({
    required this.id,
    required this.name,
    required this.typeId,
    this.typeDisplayName,
    this.description,
    this.phone,
    required this.email,
    this.website,
    required this.address,
    required this.city,
    required this.postalCode,
    required this.country,
    this.verificationStatus,
    this.rejectionReason,
    this.businessLicenseNumber,
    this.taxId,
    this.isActive,
    this.acceptsBookings,
  });

  final String id;
  final String name;
  final String typeId;
  final String? typeDisplayName;
  final String? description;
  final String? phone;
  final String email;
  final String? website;
  final String address;
  final String city;
  final String postalCode;
  final String country;
  final ChoiceEnumData? verificationStatus;
  final String? rejectionReason;
  final String? businessLicenseNumber;
  final String? taxId;
  final bool? isActive;
  final bool? acceptsBookings;

  factory OrganizationModel.fromJson(Map<String, dynamic> json) {
    return OrganizationModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      typeId: json['type']?.toString() ?? '',
      typeDisplayName: json['type_display_name'] as String?,
      description: json['description'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String? ?? '',
      website: json['website'] as String?,
      address: json['address'] as String? ?? '',
      city: json['city'] as String? ?? '',
      postalCode: json['postal_code'] as String? ?? '',
      country: json['country'] as String? ?? '',
      verificationStatus: ChoiceEnumData.parse(json['verification_status']),
      rejectionReason: json['rejection_reason'] as String?,
      businessLicenseNumber: json['business_license_number'] as String?,
      taxId: json['tax_id'] as String?,
      isActive: json['is_active'] as bool?,
      acceptsBookings: json['accepts_bookings'] as bool?,
    );
  }
}

class TeamMemberModel {
  const TeamMemberModel({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.role,
    this.phone,
    this.membershipRole,
  });

  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final ChoiceEnumData? role;
  final String? phone;
  final ChoiceEnumData? membershipRole;

  factory TeamMemberModel.fromJson(Map<String, dynamic> json) {
    return TeamMemberModel(
      id: json['id']?.toString() ?? '',
      email: json['email'] as String? ?? '',
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      role: ChoiceEnumData.parse(json['role']),
      phone: json['phone'] as String?,
      membershipRole: ChoiceEnumData.parse(json['membership_role']),
    );
  }

  String get displayName {
    final fn = firstName?.trim() ?? '';
    final ln = lastName?.trim() ?? '';
    if (fn.isEmpty && ln.isEmpty) return email;
    return '$fn $ln'.trim();
  }
}

class OrganizationAnalyticsModel {
  const OrganizationAnalyticsModel({
    required this.organizationId,
    required this.totalBookings,
    required this.revenue,
    this.currency,
    this.note,
  });

  final String organizationId;
  final int totalBookings;
  final String revenue;
  final String? currency;
  final String? note;

  factory OrganizationAnalyticsModel.fromJson(Map<String, dynamic> json) {
    return OrganizationAnalyticsModel(
      organizationId: json['organization_id']?.toString() ?? '',
      totalBookings: json['total_bookings'] is int
          ? json['total_bookings'] as int
          : int.tryParse('${json['total_bookings']}') ?? 0,
      revenue: json['revenue']?.toString() ?? '0',
      currency: json['currency'] as String?,
      note: json['note'] as String?,
    );
  }
}
