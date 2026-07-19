import 'package:vaxiil_mobile/shared/models/choice_enum_data.dart';

class ServiceCategoryModel {
  const ServiceCategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.sortOrder,
    this.description,
  });

  factory ServiceCategoryModel.fromJson(Map<String, dynamic> json) {
    return ServiceCategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String? ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String name;
  final String? description;

  /// Heroicon kebab-case name (e.g. `sparkles`).
  final String icon;
  final int sortOrder;
}

class ServiceOrganizationBrief {
  const ServiceOrganizationBrief({
    required this.id,
    required this.name,
  });

  factory ServiceOrganizationBrief.fromJson(Map<String, dynamic> json) {
    return ServiceOrganizationBrief(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }

  final String id;
  final String name;
}

class ServiceCategoryBrief {
  const ServiceCategoryBrief({
    required this.id,
    required this.name,
    required this.icon,
  });

  factory ServiceCategoryBrief.fromJson(Map<String, dynamic> json) {
    return ServiceCategoryBrief(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String? ?? '',
    );
  }

  final String id;
  final String name;
  final String icon;
}

class ServiceSubCategoryBrief {
  const ServiceSubCategoryBrief({
    required this.id,
    required this.name,
    required this.category,
  });

  factory ServiceSubCategoryBrief.fromJson(Map<String, dynamic> json) {
    return ServiceSubCategoryBrief(
      id: json['id'] as String,
      name: json['name'] as String,
      category: ServiceCategoryBrief.fromJson(
        json['category'] as Map<String, dynamic>,
      ),
    );
  }

  final String id;
  final String name;
  final ServiceCategoryBrief category;
}

class ServiceListItemModel {
  const ServiceListItemModel({
    required this.id,
    required this.name,
    required this.description,
    required this.priceMin,
    required this.priceMax,
    required this.currency,
    required this.featured,
    required this.organization,
    required this.subCategory,
    this.primaryImage,
    this.averageRating,
    this.ratingCount,
    this.isFavorite = false,
  });

  factory ServiceListItemModel.fromJson(Map<String, dynamic> json) {
    return ServiceListItemModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      priceMin: _parseNum(json['price_min']),
      priceMax: _parseNum(json['price_max']),
      currency: currencyCodeFromAcceptedJson(json),
      featured: json['featured'] as bool? ?? false,
      organization: ServiceOrganizationBrief.fromJson(
        json['organization'] as Map<String, dynamic>,
      ),
      subCategory: ServiceSubCategoryBrief.fromJson(
        json['sub_category'] as Map<String, dynamic>,
      ),
      primaryImage: json['primary_image'] as String?,
      averageRating: _parseDoubleNullable(json['average_rating']),
      ratingCount: (json['rating_count'] as num?)?.toInt(),
      isFavorite: json['is_favorite'] as bool? ?? false,
    );
  }

  final String id;
  final String name;
  final String description;
  final num priceMin;
  final num priceMax;
  final String currency;
  final bool featured;
  final ServiceOrganizationBrief organization;
  final ServiceSubCategoryBrief subCategory;
  final String? primaryImage;

  /// Aggregate rating when backend exposes reviews (nullable until wired).
  final double? averageRating;

  /// Number of ratings contributing to [averageRating].
  final int? ratingCount;

  /// Server-side favorite flag; client may also track favorites locally.
  final bool isFavorite;

  /// One decimal place for UI badges; empty if no rating yet.
  String? get ratingLabel {
    final r = averageRating;
    if (r == null) {
      return null;
    }
    return r.toStringAsFixed(1);
  }

  ServiceListItemModel copyWith({
    String? id,
    String? name,
    String? description,
    num? priceMin,
    num? priceMax,
    String? currency,
    bool? featured,
    ServiceOrganizationBrief? organization,
    ServiceSubCategoryBrief? subCategory,
    String? primaryImage,
    double? averageRating,
    int? ratingCount,
    bool? isFavorite,
  }) {
    return ServiceListItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      priceMin: priceMin ?? this.priceMin,
      priceMax: priceMax ?? this.priceMax,
      currency: currency ?? this.currency,
      featured: featured ?? this.featured,
      organization: organization ?? this.organization,
      subCategory: subCategory ?? this.subCategory,
      primaryImage: primaryImage ?? this.primaryImage,
      averageRating: averageRating ?? this.averageRating,
      ratingCount: ratingCount ?? this.ratingCount,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

double? _parseDoubleNullable(dynamic v) {
  if (v == null) {
    return null;
  }
  if (v is num) {
    return v.toDouble();
  }
  return double.tryParse(v.toString());
}

num _parseNum(dynamic v) {
  if (v == null) {
    return 0;
  }
  if (v is num) {
    return v;
  }
  return num.parse(v.toString());
}

/// ISO 4217 code from nested `accepted_currency.currency`.
String currencyCodeFromAcceptedJson(Map<String, dynamic> json) {
  final ac = json['accepted_currency'];
  if (ac is Map<String, dynamic>) {
    final c = ac['currency'];
    if (c is Map<String, dynamic>) {
      return c['code'] as String? ?? 'USD';
    }
  }
  return 'USD';
}

String _countryDisplayFromJson(Map<String, dynamic> json) {
  final c = json['country'];
  if (c is Map<String, dynamic>) {
    return c['name'] as String? ?? c['iso_code2'] as String? ?? '';
  }
  return json['country_text'] as String? ?? '';
}

class ServiceOrgDetailModel {
  const ServiceOrgDetailModel({
    required this.id,
    required this.name,
    this.requireClientName = false,
    this.verificationStatus,
  });

  factory ServiceOrgDetailModel.fromJson(Map<String, dynamic> json) {
    final vs = json['verification_status'];
    return ServiceOrgDetailModel(
      id: json['id'] as String,
      name: json['name'] as String,
      requireClientName: json['require_client_name'] as bool? ?? false,
      verificationStatus:
          vs is Map<String, dynamic> ? ChoiceEnumData.parse(vs) : null,
    );
  }

  final String id;
  final String name;
  final bool requireClientName;
  final ChoiceEnumData? verificationStatus;
}

class ServiceVariantDetailModel {
  const ServiceVariantDetailModel({
    required this.id,
    required this.name,
    required this.durationMinutes,
    required this.price,
    required this.isPopular,
    required this.isActive,
    this.durationType,
  });

  factory ServiceVariantDetailModel.fromJson(Map<String, dynamic> json) {
    return ServiceVariantDetailModel(
      id: json['id'] as String,
      name: json['name'] as String,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 0,
      durationType: ChoiceEnumData.parse(json['duration_type']),
      price: _parseNum(json['price']),
      isPopular: json['is_popular'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  final String id;
  final String name;
  final int durationMinutes;
  final ChoiceEnumData? durationType;
  final num price;
  final bool isPopular;
  final bool isActive;
}

class ServiceMediaItemModel {
  const ServiceMediaItemModel({
    required this.id,
    required this.sortOrder,
    required this.isPrimary,
    this.mediaType,
    this.fileUrl,
    this.title,
    this.description,
  });

  factory ServiceMediaItemModel.fromJson(Map<String, dynamic> json) {
    return ServiceMediaItemModel(
      id: json['id'] as String,
      mediaType: json['media_type'] as String?,
      fileUrl: json['file'] as String?,
      title: json['title'] as String?,
      description: json['description'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isPrimary: json['is_primary'] as bool? ?? false,
    );
  }

  final String id;
  final String? mediaType;
  final String? fileUrl;
  final String? title;
  final String? description;
  final int sortOrder;
  final bool isPrimary;
}

class ServiceFeatureItemModel {
  const ServiceFeatureItemModel({
    required this.id,
    required this.name,
    this.featureType,
    this.description,
    this.icon,
  });

  factory ServiceFeatureItemModel.fromJson(Map<String, dynamic> json) {
    return ServiceFeatureItemModel(
      id: json['id'] as String,
      name: json['name'] as String,
      featureType: ChoiceEnumData.parse(json['feature_type']),
      description: json['description'] as String?,
      icon: json['icon'] as String?,
    );
  }

  final String id;
  final String name;
  final ChoiceEnumData? featureType;
  final String? description;
  final String? icon;
}

class ServiceFeatureMappingRowModel {
  const ServiceFeatureMappingRowModel({
    required this.id,
    required this.feature,
    required this.isRequired,
  });

  factory ServiceFeatureMappingRowModel.fromJson(Map<String, dynamic> json) {
    return ServiceFeatureMappingRowModel(
      id: json['id'] as String,
      feature: ServiceFeatureItemModel.fromJson(
        json['feature'] as Map<String, dynamic>,
      ),
      isRequired: json['is_required'] as bool? ?? false,
    );
  }

  final String id;
  final ServiceFeatureItemModel feature;
  final bool isRequired;
}

/// Full service payload from `GET /api/v1/services/{id}/`.
class ServiceDetailModel {
  const ServiceDetailModel({
    required this.id,
    required this.name,
    required this.description,
    required this.priceMin,
    required this.priceMax,
    required this.currency,
    required this.showLocationOnListing,
    required this.featured,
    required this.requiresVerification,
    required this.isActive,
    required this.address,
    required this.city,
    required this.postalCode,
    required this.country,
    required this.organization,
    required this.subCategory,
    required this.variants,
    required this.media,
    required this.featureMappings,
    this.availabilityType,
    this.latitude,
    this.longitude,
    this.maxBookingsPerDay,
    this.maxBookingsPerTimeSlot,
    this.bookingAdvanceDays,
    this.minimumBookingHours,
    this.cancellationHours,
    this.availableStartTime,
    this.availableEndTime,
    this.availableDays,
    this.seasonalStartDate,
    this.seasonalEndDate,
    this.availabilityNotes,
    this.primaryImage,
    this.averageRating,
    this.ratingCount,
  });

  factory ServiceDetailModel.fromJson(Map<String, dynamic> json) {
    final days = json['available_days'];
    return ServiceDetailModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      priceMin: _parseNum(json['price_min']),
      priceMax: _parseNum(json['price_max']),
      currency: currencyCodeFromAcceptedJson(json),
      showLocationOnListing: json['show_location_on_listing'] as bool? ?? true,
      featured: json['featured'] as bool? ?? false,
      requiresVerification: json['requires_verification'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
      availabilityType: ChoiceEnumData.parse(json['availability_type']),
      address: json['address'] as String? ?? '',
      city: json['city'] as String? ?? '',
      postalCode: json['postal_code'] as String? ?? '',
      country: _countryDisplayFromJson(json),
      latitude: json['latitude'] != null ? _parseNum(json['latitude']) : null,
      longitude:
          json['longitude'] != null ? _parseNum(json['longitude']) : null,
      maxBookingsPerDay: (json['max_bookings_per_day'] as num?)?.toInt(),
      maxBookingsPerTimeSlot:
          (json['max_bookings_per_time_slot'] as num?)?.toInt(),
      bookingAdvanceDays: (json['booking_advance_days'] as num?)?.toInt(),
      minimumBookingHours: (json['minimum_booking_hours'] as num?)?.toInt(),
      cancellationHours: (json['cancellation_hours'] as num?)?.toInt(),
      availableStartTime: json['available_start_time'] as String?,
      availableEndTime: json['available_end_time'] as String?,
      availableDays:
          days is List ? days.map((e) => e.toString()).toList() : null,
      seasonalStartDate: json['seasonal_start_date'] as String?,
      seasonalEndDate: json['seasonal_end_date'] as String?,
      availabilityNotes: json['availability_notes'] as String?,
      organization: ServiceOrgDetailModel.fromJson(
        json['organization'] as Map<String, dynamic>,
      ),
      subCategory: ServiceSubCategoryBrief.fromJson(
        json['sub_category'] as Map<String, dynamic>,
      ),
      primaryImage: json['primary_image'] as String?,
      variants: (json['variants'] as List<dynamic>?)
              ?.map(
                (e) => ServiceVariantDetailModel.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          const [],
      media: (json['media'] as List<dynamic>?)
              ?.map(
                (e) => ServiceMediaItemModel.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          const [],
      featureMappings: (json['feature_mappings'] as List<dynamic>?)
              ?.map(
                (e) => ServiceFeatureMappingRowModel.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          const [],
      averageRating: _parseDoubleNullable(json['average_rating']),
      ratingCount: (json['rating_count'] as num?)?.toInt(),
    );
  }

  final String id;
  final String name;
  final String description;
  final num priceMin;
  final num priceMax;
  final String currency;
  final bool showLocationOnListing;
  final bool featured;
  final bool requiresVerification;
  final bool isActive;
  final ChoiceEnumData? availabilityType;
  final String address;
  final String city;
  final String postalCode;
  final String country;
  final num? latitude;
  final num? longitude;
  final int? maxBookingsPerDay;
  final int? maxBookingsPerTimeSlot;
  final int? bookingAdvanceDays;
  final int? minimumBookingHours;
  final int? cancellationHours;
  final String? availableStartTime;
  final String? availableEndTime;
  final List<String>? availableDays;
  final String? seasonalStartDate;
  final String? seasonalEndDate;
  final String? availabilityNotes;
  final ServiceOrgDetailModel organization;
  final ServiceSubCategoryBrief subCategory;
  final String? primaryImage;
  final List<ServiceVariantDetailModel> variants;
  final List<ServiceMediaItemModel> media;
  final List<ServiceFeatureMappingRowModel> featureMappings;

  /// Aggregate rating when API exposes reviews (nullable until wired).
  final double? averageRating;
  final int? ratingCount;

  String? get ratingLabel {
    final r = averageRating;
    if (r == null) {
      return null;
    }
    return r.toStringAsFixed(1);
  }
}
