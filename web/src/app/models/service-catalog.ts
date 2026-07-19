import { ChoiceEnum, parseChoiceEnum } from './choice-enum';

export interface ServiceCategory {
  id: string;
  name: string;
  description: string | null;
  icon: string;
  sortOrder: number;
}

export interface ServiceOrganizationBrief {
  id: string;
  name: string;
}

export interface ServiceCategoryBrief {
  id: string;
  name: string;
  icon: string;
}

export interface ServiceSubCategoryBrief {
  id: string;
  name: string;
  category: ServiceCategoryBrief;
}

export interface ServiceListItem {
  id: string;
  name: string;
  description: string;
  priceMin: number;
  priceMax: number;
  currency: string;
  featured: boolean;
  organization: ServiceOrganizationBrief;
  subCategory: ServiceSubCategoryBrief;
  primaryImage: string | null;
  averageRating: number | null;
  ratingCount: number | null;
  isFavorite: boolean;
}

export interface ServiceOrgDetail {
  id: string;
  name: string;
  verificationStatus: ChoiceEnum | null;
  requireClientName?: boolean;
}

export interface ServiceVariantDetail {
  id: string;
  name: string;
  durationMinutes: number;
  durationType: ChoiceEnum | null;
  price: number;
  isPopular: boolean;
  isActive: boolean;
}

export interface ServiceMediaItem {
  id: string;
  mediaType: string | null;
  fileUrl: string | null;
  title: string | null;
  description: string | null;
  sortOrder: number;
  isPrimary: boolean;
}

export interface ServiceFeatureItem {
  id: string;
  name: string;
  featureType: ChoiceEnum | null;
  description: string | null;
  icon: string | null;
}

export interface ServiceFeatureMappingRow {
  id: string;
  feature: ServiceFeatureItem;
  isRequired: boolean;
}

export interface ServiceDetail {
  id: string;
  name: string;
  description: string;
  priceMin: number;
  priceMax: number;
  currency: string;
  showLocationOnListing: boolean;
  featured: boolean;
  requiresVerification: boolean;
  isActive: boolean;
  availabilityType: ChoiceEnum | null;
  address: string;
  city: string;
  postalCode: string;
  country: string;
  latitude: number | null;
  longitude: number | null;
  maxBookingsPerDay: number | null;
  maxBookingsPerTimeSlot: number | null;
  bookingAdvanceDays: number | null;
  minimumBookingHours: number | null;
  cancellationHours: number | null;
  availableStartTime: string | null;
  availableEndTime: string | null;
  availableDays: string[] | null;
  seasonalStartDate: string | null;
  seasonalEndDate: string | null;
  availabilityNotes: string | null;
  organization: ServiceOrgDetail;
  subCategory: ServiceSubCategoryBrief;
  primaryImage: string | null;
  variants: ServiceVariantDetail[];
  media: ServiceMediaItem[];
  featureMappings: ServiceFeatureMappingRow[];
  averageRating: number | null;
  ratingCount: number | null;
}

function parseNum(value: unknown): number {
  if (value == null) {
    return 0;
  }
  if (typeof value === 'number') {
    return value;
  }
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function parseDoubleNullable(value: unknown): number | null {
  if (value == null) {
    return null;
  }
  if (typeof value === 'number') {
    return value;
  }
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

/** ISO 4217 code from nested `accepted_currency.currency`. */
export function currencyCodeFromAcceptedJson(json: Record<string, unknown>): string {
  const ac = json['accepted_currency'];
  if (ac && typeof ac === 'object' && !Array.isArray(ac)) {
    const currency = (ac as Record<string, unknown>)['currency'];
    if (currency && typeof currency === 'object' && !Array.isArray(currency)) {
      const code = (currency as Record<string, unknown>)['code'];
      if (typeof code === 'string' && code) {
        return code;
      }
    }
  }
  return 'USD';
}

function countryDisplayFromJson(json: Record<string, unknown>): string {
  const country = json['country'];
  if (country && typeof country === 'object' && !Array.isArray(country)) {
    const c = country as Record<string, unknown>;
    if (typeof c['name'] === 'string') {
      return c['name'];
    }
    if (typeof c['iso_code2'] === 'string') {
      return c['iso_code2'];
    }
  }
  return typeof json['country_text'] === 'string' ? json['country_text'] : '';
}

export function parseServiceCategory(json: Record<string, unknown>): ServiceCategory {
  return {
    id: json['id'] != null ? String(json['id']) : '',
    name: typeof json['name'] === 'string' ? json['name'] : '',
    description: typeof json['description'] === 'string' ? json['description'] : null,
    icon: typeof json['icon'] === 'string' ? json['icon'] : '',
    sortOrder: typeof json['sort_order'] === 'number' ? json['sort_order'] : 0,
  };
}

export function parseServiceOrganizationBrief(
  json: Record<string, unknown>,
): ServiceOrganizationBrief {
  return {
    id: json['id'] != null ? String(json['id']) : '',
    name: typeof json['name'] === 'string' ? json['name'] : '',
  };
}

export function parseServiceCategoryBrief(json: Record<string, unknown>): ServiceCategoryBrief {
  return {
    id: json['id'] != null ? String(json['id']) : '',
    name: typeof json['name'] === 'string' ? json['name'] : '',
    icon: typeof json['icon'] === 'string' ? json['icon'] : '',
  };
}

export function parseServiceSubCategoryBrief(
  json: Record<string, unknown>,
): ServiceSubCategoryBrief {
  const categoryRaw = json['category'];
  return {
    id: json['id'] != null ? String(json['id']) : '',
    name: typeof json['name'] === 'string' ? json['name'] : '',
    category:
      categoryRaw && typeof categoryRaw === 'object' && !Array.isArray(categoryRaw)
        ? parseServiceCategoryBrief(categoryRaw as Record<string, unknown>)
        : { id: '', name: '', icon: '' },
  };
}

export function parseServiceListItem(json: Record<string, unknown>): ServiceListItem {
  const orgRaw = json['organization'];
  const subRaw = json['sub_category'];
  return {
    id: json['id'] != null ? String(json['id']) : '',
    name: typeof json['name'] === 'string' ? json['name'] : '',
    description: typeof json['description'] === 'string' ? json['description'] : '',
    priceMin: parseNum(json['price_min']),
    priceMax: parseNum(json['price_max']),
    currency: currencyCodeFromAcceptedJson(json),
    featured: json['featured'] === true,
    organization:
      orgRaw && typeof orgRaw === 'object' && !Array.isArray(orgRaw)
        ? parseServiceOrganizationBrief(orgRaw as Record<string, unknown>)
        : { id: '', name: '' },
    subCategory:
      subRaw && typeof subRaw === 'object' && !Array.isArray(subRaw)
        ? parseServiceSubCategoryBrief(subRaw as Record<string, unknown>)
        : {
            id: '',
            name: '',
            category: { id: '', name: '', icon: '' },
          },
    primaryImage: typeof json['primary_image'] === 'string' ? json['primary_image'] : null,
    averageRating: parseDoubleNullable(json['average_rating']),
    ratingCount: typeof json['rating_count'] === 'number' ? json['rating_count'] : null,
    isFavorite: json['is_favorite'] === true,
  };
}

export function parseServiceOrgDetail(json: Record<string, unknown>): ServiceOrgDetail {
  return {
    id: json['id'] != null ? String(json['id']) : '',
    name: typeof json['name'] === 'string' ? json['name'] : '',
    verificationStatus: parseChoiceEnum(json['verification_status']),
    requireClientName: json['require_client_name'] === true,
  };
}

export function parseServiceVariantDetail(json: Record<string, unknown>): ServiceVariantDetail {
  return {
    id: json['id'] != null ? String(json['id']) : '',
    name: typeof json['name'] === 'string' ? json['name'] : '',
    durationMinutes: typeof json['duration_minutes'] === 'number' ? json['duration_minutes'] : 0,
    durationType: parseChoiceEnum(json['duration_type']),
    price: parseNum(json['price']),
    isPopular: json['is_popular'] === true,
    isActive: json['is_active'] !== false,
  };
}

export function parseServiceMediaItem(json: Record<string, unknown>): ServiceMediaItem {
  return {
    id: json['id'] != null ? String(json['id']) : '',
    mediaType: typeof json['media_type'] === 'string' ? json['media_type'] : null,
    fileUrl: typeof json['file'] === 'string' ? json['file'] : null,
    title: typeof json['title'] === 'string' ? json['title'] : null,
    description: typeof json['description'] === 'string' ? json['description'] : null,
    sortOrder: typeof json['sort_order'] === 'number' ? json['sort_order'] : 0,
    isPrimary: json['is_primary'] === true,
  };
}

export function parseServiceFeatureItem(json: Record<string, unknown>): ServiceFeatureItem {
  return {
    id: json['id'] != null ? String(json['id']) : '',
    name: typeof json['name'] === 'string' ? json['name'] : '',
    featureType: parseChoiceEnum(json['feature_type']),
    description: typeof json['description'] === 'string' ? json['description'] : null,
    icon: typeof json['icon'] === 'string' ? json['icon'] : null,
  };
}

export function parseServiceFeatureMappingRow(
  json: Record<string, unknown>,
): ServiceFeatureMappingRow {
  const featureRaw = json['feature'];
  return {
    id: json['id'] != null ? String(json['id']) : '',
    feature:
      featureRaw && typeof featureRaw === 'object' && !Array.isArray(featureRaw)
        ? parseServiceFeatureItem(featureRaw as Record<string, unknown>)
        : { id: '', name: '', featureType: null, description: null, icon: null },
    isRequired: json['is_required'] === true,
  };
}

export function parseServiceDetail(json: Record<string, unknown>): ServiceDetail {
  const days = json['available_days'];
  const variantsRaw = json['variants'];
  const mediaRaw = json['media'];
  const mappingsRaw = json['feature_mappings'];
  const orgRaw = json['organization'];
  const subRaw = json['sub_category'];

  return {
    id: json['id'] != null ? String(json['id']) : '',
    name: typeof json['name'] === 'string' ? json['name'] : '',
    description: typeof json['description'] === 'string' ? json['description'] : '',
    priceMin: parseNum(json['price_min']),
    priceMax: parseNum(json['price_max']),
    currency: currencyCodeFromAcceptedJson(json),
    showLocationOnListing: json['show_location_on_listing'] !== false,
    featured: json['featured'] === true,
    requiresVerification: json['requires_verification'] !== false,
    isActive: json['is_active'] !== false,
    availabilityType: parseChoiceEnum(json['availability_type']),
    address: typeof json['address'] === 'string' ? json['address'] : '',
    city: typeof json['city'] === 'string' ? json['city'] : '',
    postalCode: typeof json['postal_code'] === 'string' ? json['postal_code'] : '',
    country: countryDisplayFromJson(json),
    latitude: json['latitude'] != null ? parseNum(json['latitude']) : null,
    longitude: json['longitude'] != null ? parseNum(json['longitude']) : null,
    maxBookingsPerDay:
      typeof json['max_bookings_per_day'] === 'number' ? json['max_bookings_per_day'] : null,
    maxBookingsPerTimeSlot:
      typeof json['max_bookings_per_time_slot'] === 'number'
        ? json['max_bookings_per_time_slot']
        : null,
    bookingAdvanceDays:
      typeof json['booking_advance_days'] === 'number' ? json['booking_advance_days'] : null,
    minimumBookingHours:
      typeof json['minimum_booking_hours'] === 'number' ? json['minimum_booking_hours'] : null,
    cancellationHours:
      typeof json['cancellation_hours'] === 'number' ? json['cancellation_hours'] : null,
    availableStartTime:
      typeof json['available_start_time'] === 'string' ? json['available_start_time'] : null,
    availableEndTime:
      typeof json['available_end_time'] === 'string' ? json['available_end_time'] : null,
    availableDays: Array.isArray(days) ? days.map((d) => String(d)) : null,
    seasonalStartDate:
      typeof json['seasonal_start_date'] === 'string' ? json['seasonal_start_date'] : null,
    seasonalEndDate:
      typeof json['seasonal_end_date'] === 'string' ? json['seasonal_end_date'] : null,
    availabilityNotes:
      typeof json['availability_notes'] === 'string' ? json['availability_notes'] : null,
    organization:
      orgRaw && typeof orgRaw === 'object' && !Array.isArray(orgRaw)
        ? parseServiceOrgDetail(orgRaw as Record<string, unknown>)
        : { id: '', name: '', verificationStatus: null, requireClientName: false },
    subCategory:
      subRaw && typeof subRaw === 'object' && !Array.isArray(subRaw)
        ? parseServiceSubCategoryBrief(subRaw as Record<string, unknown>)
        : {
            id: '',
            name: '',
            category: { id: '', name: '', icon: '' },
          },
    primaryImage: typeof json['primary_image'] === 'string' ? json['primary_image'] : null,
    variants: Array.isArray(variantsRaw)
      ? variantsRaw
          .filter((e) => e && typeof e === 'object' && !Array.isArray(e))
          .map((e) => parseServiceVariantDetail(e as Record<string, unknown>))
      : [],
    media: Array.isArray(mediaRaw)
      ? mediaRaw
          .filter((e) => e && typeof e === 'object' && !Array.isArray(e))
          .map((e) => parseServiceMediaItem(e as Record<string, unknown>))
      : [],
    featureMappings: Array.isArray(mappingsRaw)
      ? mappingsRaw
          .filter((e) => e && typeof e === 'object' && !Array.isArray(e))
          .map((e) => parseServiceFeatureMappingRow(e as Record<string, unknown>))
      : [],
    averageRating: parseDoubleNullable(json['average_rating']),
    ratingCount: typeof json['rating_count'] === 'number' ? json['rating_count'] : null,
  };
}

export function serviceRatingLabel(item: Pick<ServiceListItem, 'averageRating'>): string | null {
  const rating = item.averageRating;
  if (rating == null) {
    return null;
  }
  return rating.toFixed(1);
}

export function formatServicePrice(amount: number, currency: string): string {
  try {
    return new Intl.NumberFormat(undefined, {
      style: 'currency',
      currency,
      maximumFractionDigits: 0,
    }).format(amount);
  } catch {
    return `${amount} ${currency}`;
  }
}
