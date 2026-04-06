import 'package:vaxiil_mobile/shared/models/choice_enum_data.dart';

class CountryBriefModel {
  const CountryBriefModel({
    required this.id,
    required this.isoCode2,
    required this.name,
  });

  factory CountryBriefModel.fromJson(Map<String, dynamic> json) {
    return CountryBriefModel(
      id: json['id']?.toString() ?? '',
      isoCode2: json['iso_code2'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }

  final String id;
  final String isoCode2;
  final String name;
}

class OrganizationTypeOption {
  const OrganizationTypeOption({
    required this.id,
    required this.name,
    required this.displayName,
    this.description,
    this.icon,
  });

  factory OrganizationTypeOption.fromJson(Map<String, dynamic> json) {
    return OrganizationTypeOption(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      description: json['description'] as String?,
      icon: json['icon'] as String?,
    );
  }

  final String id;
  final String name;
  final String displayName;
  final String? description;
  final String? icon;
}

class OrganizationModel {
  const OrganizationModel({
    required this.id,
    required this.name,
    required this.typeId,
    required this.email, required this.address, required this.city, required this.postalCode, required this.country, this.typeDisplayName,
    this.countryId,
    this.defaultCurrencyId,
    this.description,
    this.phone,
    this.website,
    this.logoUrl,
    this.verificationStatus,
    this.rejectionReason,
    this.businessLicenseNumber,
    this.taxId,
    this.isActive,
    this.acceptsBookings,
    this.kybSubmittedAt,
  });

  factory OrganizationModel.fromJson(Map<String, dynamic> json) {
    final countryField = json['country'];
    String countryName = '';
    String? countryId;
    if (countryField is Map<String, dynamic>) {
      countryId = countryField['id']?.toString();
      countryName = countryField['name'] as String? ??
          countryField['iso_code2'] as String? ??
          '';
    } else if (countryField is String) {
      countryName = countryField;
    }
    final dc = json['default_currency'];
    String? defaultCurrencyId;
    if (dc is Map<String, dynamic>) {
      defaultCurrencyId = dc['id']?.toString();
    }
    return OrganizationModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      typeId: json['type']?.toString() ?? '',
      typeDisplayName: json['type_display_name'] as String?,
      description: json['description'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String? ?? '',
      website: json['website'] as String?,
      logoUrl: json['logo'] as String?,
      address: json['address'] as String? ?? '',
      city: json['city'] as String? ?? '',
      postalCode: json['postal_code'] as String? ?? '',
      country: countryName,
      countryId: countryId,
      defaultCurrencyId: defaultCurrencyId,
      verificationStatus: ChoiceEnumData.parse(json['verification_status']),
      rejectionReason: json['rejection_reason'] as String?,
      businessLicenseNumber: json['business_license_number'] as String?,
      taxId: json['tax_id'] as String?,
      isActive: json['is_active'] as bool?,
      acceptsBookings: json['accepts_bookings'] as bool?,
      kybSubmittedAt: json['kyb_submitted_at'] != null
          ? DateTime.tryParse(json['kyb_submitted_at'] as String)
          : null,
    );
  }

  final String id;
  final String name;
  final String typeId;
  final String? typeDisplayName;
  final String? description;
  final String? phone;
  final String email;
  final String? website;
  final String? logoUrl;
  final String address;
  final String city;
  final String postalCode;
  final String country;
  final String? countryId;
  final String? defaultCurrencyId;
  final ChoiceEnumData? verificationStatus;
  final String? rejectionReason;
  final String? businessLicenseNumber;
  final String? taxId;
  final bool? isActive;
  final bool? acceptsBookings;
  /// ISO 8601; set after KYB documents are submitted (pending review).
  final DateTime? kybSubmittedAt;

  /// Organization verified after KYB review (`verification_status` code `V`).
  bool get isVerified => verificationStatus?.value == 'V';
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

  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final ChoiceEnumData? role;
  final String? phone;
  final ChoiceEnumData? membershipRole;

  String get displayName {
    final fn = firstName?.trim() ?? '';
    final ln = lastName?.trim() ?? '';
    if (fn.isEmpty && ln.isEmpty) return email;
    return '$fn $ln'.trim();
  }
}

/// Lightweight org row from [AppConstants.organizationsDiscoveryPath].
class OrganizationDiscoveryModel {
  const OrganizationDiscoveryModel({
    required this.id,
    required this.name,
    required this.description,
    required this.city,
    this.logoUrl,
  });

  factory OrganizationDiscoveryModel.fromJson(Map<String, dynamic> json) {
    return OrganizationDiscoveryModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      city: json['city'] as String? ?? '',
      logoUrl: json['logo'] as String?,
    );
  }

  final String id;
  final String name;
  final String description;
  final String city;
  final String? logoUrl;
}

class OrganizationAnalyticsModel {
  const OrganizationAnalyticsModel({
    required this.organizationId,
    required this.totalBookings,
    required this.revenue,
    this.currency,
    this.note,
  });

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

  final String organizationId;
  final int totalBookings;
  final String revenue;
  final String? currency;
  final String? note;
}
