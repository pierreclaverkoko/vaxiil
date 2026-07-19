import 'package:vaxiil_mobile/shared/models/choice_enum_data.dart';

double? _parseDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

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

class OrganizationMineSummaryModel {
  const OrganizationMineSummaryModel({
    required this.organizationCount,
    required this.collectiveBeneficiaries,
  });

  factory OrganizationMineSummaryModel.fromJson(Map<String, dynamic> json) {
    return OrganizationMineSummaryModel(
      organizationCount: json['organization_count'] is int
          ? json['organization_count'] as int
          : int.tryParse('${json['organization_count']}') ?? 0,
      collectiveBeneficiaries: json['collective_beneficiaries'] is int
          ? json['collective_beneficiaries'] as int
          : int.tryParse('${json['collective_beneficiaries']}') ?? 0,
    );
  }

  final int organizationCount;
  final int collectiveBeneficiaries;
}

/// Read-only fee summary on `OrganizationSerializer.platform_fees`.
class OrganizationPlatformFeesModel {
  const OrganizationPlatformFeesModel({
    required this.platformFeeRate,
    this.platformFeePayer,
    this.platformFeeSource,
    this.hasOrganizationOverride = false,
    this.globalPlatformFeeRate,
    this.organizationPlatformFeeRate,
    this.note,
  });

  factory OrganizationPlatformFeesModel.fromJson(Map<String, dynamic> json) {
    return OrganizationPlatformFeesModel(
      platformFeeRate: json['platform_fee_rate']?.toString() ?? '0',
      platformFeePayer: ChoiceEnumData.parse(json['platform_fee_payer']),
      platformFeeSource: ChoiceEnumData.parse(json['platform_fee_source']),
      hasOrganizationOverride:
          json['has_organization_override'] as bool? ?? false,
      globalPlatformFeeRate: json['global_platform_fee_rate']?.toString(),
      organizationPlatformFeeRate:
          json['organization_platform_fee_rate']?.toString(),
      note: json['note'] as String?,
    );
  }

  final String platformFeeRate;
  final ChoiceEnumData? platformFeePayer;
  final ChoiceEnumData? platformFeeSource;
  final bool hasOrganizationOverride;
  final String? globalPlatformFeeRate;
  final String? organizationPlatformFeeRate;
  final String? note;
}

class OrganizationModel {
  const OrganizationModel({
    required this.id,
    required this.name,
    required this.typeId,
    required this.email,
    required this.address,
    required this.city,
    required this.postalCode,
    required this.country,
    this.typeDisplayName,
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
    this.requireClientName = true,
    this.kybSubmittedAt,
    this.myMembershipRole,
    this.latitude,
    this.longitude,
    this.updatedAt,
    this.platformFees,
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
    OrganizationPlatformFeesModel? platformFees;
    final rawFees = json['platform_fees'];
    if (rawFees is Map<String, dynamic>) {
      platformFees = OrganizationPlatformFeesModel.fromJson(rawFees);
    }
    return OrganizationModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      typeId: json['type']?.toString() ?? '',
      typeDisplayName: json['type_display_name'] as String?,
      myMembershipRole: ChoiceEnumData.parse(json['my_membership_role']),
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
      requireClientName: json['require_client_name'] as bool? ?? true,
      kybSubmittedAt: json['kyb_submitted_at'] != null
          ? DateTime.tryParse(json['kyb_submitted_at'] as String)
          : null,
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      platformFees: platformFees,
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
  final bool requireClientName;

  /// ISO 8601; set after KYB documents are submitted (pending review).
  final DateTime? kybSubmittedAt;

  /// Current user’s role on this organization (from membership), when applicable.
  final ChoiceEnumData? myMembershipRole;

  /// Primary address latitude from API (when set).
  final double? latitude;

  /// Primary address longitude from API (when set).
  final double? longitude;

  /// Server `updated_at` (ISO 8601), when present.
  final DateTime? updatedAt;

  /// Read-only platform fee settings for this organization.
  final OrganizationPlatformFeesModel? platformFees;

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
    required this.confirmedBookings,
    required this.completedBookings,
    required this.cancelledBookings,
    required this.revenue,
    this.grossRevenue,
    this.platformFees,
    this.netRevenue,
    this.currency,
    this.note,
  });

  factory OrganizationAnalyticsModel.fromJson(Map<String, dynamic> json) {
    final revenue = json['revenue']?.toString() ?? '0';
    return OrganizationAnalyticsModel(
      organizationId: json['organization_id']?.toString() ?? '',
      totalBookings: json['total_bookings'] is int
          ? json['total_bookings'] as int
          : int.tryParse('${json['total_bookings']}') ?? 0,
      confirmedBookings: json['confirmed_bookings'] is int
          ? json['confirmed_bookings'] as int
          : int.tryParse('${json['confirmed_bookings']}') ?? 0,
      completedBookings: json['completed_bookings'] is int
          ? json['completed_bookings'] as int
          : int.tryParse('${json['completed_bookings']}') ?? 0,
      cancelledBookings: json['cancelled_bookings'] is int
          ? json['cancelled_bookings'] as int
          : int.tryParse('${json['cancelled_bookings']}') ?? 0,
      revenue: revenue,
      grossRevenue: json['gross_revenue']?.toString() ?? revenue,
      platformFees: json['platform_fees']?.toString(),
      netRevenue: json['net_revenue']?.toString(),
      currency: json['currency'] as String?,
      note: json['note'] as String?,
    );
  }

  final String organizationId;
  final int totalBookings;
  final int confirmedBookings;
  final int completedBookings;
  final int cancelledBookings;

  /// Legacy alias; equals gross revenue when API sends both.
  final String revenue;
  final String? grossRevenue;
  final String? platformFees;
  final String? netRevenue;
  final String? currency;
  final String? note;
}
