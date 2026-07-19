import { ChoiceEnum, parseChoiceEnum } from './choice-enum';

export interface CountryBrief {
  id: string;
  isoCode2: string;
  name: string;
}

export interface OrganizationTypeOption {
  id: string;
  name: string;
  displayName: string;
  description: string | null;
  icon: string | null;
}

export interface OrganizationMineSummary {
  organizationCount: number;
  collectiveBeneficiaries: number;
}

export interface OrganizationPlatformFees {
  platformFeeRate: string;
  platformFeeSource: ChoiceEnum | null;
  platformFeePayer: ChoiceEnum | null;
  hasOrganizationOverride: boolean;
  globalPlatformFeeRate: string;
  organizationPlatformFeeRate: string | null;
  note: string | null;
}

export interface Organization {
  id: string;
  name: string;
  typeId: string;
  typeDisplayName: string | null;
  email: string;
  address: string;
  city: string;
  postalCode: string;
  country: string;
  countryId: string | null;
  defaultCurrencyId: string | null;
  description: string | null;
  phone: string | null;
  website: string | null;
  logoUrl: string | null;
  verificationStatus: ChoiceEnum | null;
  rejectionReason: string | null;
  businessLicenseNumber: string | null;
  taxId: string | null;
  isActive: boolean | null;
  acceptsBookings: boolean | null;
  requireClientName: boolean;
  kybSubmittedAt: string | null;
  myMembershipRole: ChoiceEnum | null;
  latitude: number | null;
  longitude: number | null;
  platformFees: OrganizationPlatformFees | null;
}

export interface TeamMember {
  id: string;
  email: string;
  firstName: string | null;
  lastName: string | null;
  phone: string | null;
  role: ChoiceEnum | null;
  membershipRole: ChoiceEnum | null;
}

export interface OrganizationAnalytics {
  organizationId: string;
  totalBookings: number;
  confirmedBookings: number;
  completedBookings: number;
  cancelledBookings: number;
  revenue: string;
  grossRevenue: string | null;
  platformFees: string | null;
  netRevenue: string | null;
  currency: string | null;
}

function parseDouble(v: unknown): number | null {
  if (v == null) {
    return null;
  }
  if (typeof v === 'number') {
    return v;
  }
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

export function parseCountryBrief(json: Record<string, unknown>): CountryBrief {
  return {
    id: json['id'] != null ? String(json['id']) : '',
    isoCode2: typeof json['iso_code2'] === 'string' ? json['iso_code2'] : '',
    name: typeof json['name'] === 'string' ? json['name'] : '',
  };
}

export function parseOrganizationType(json: Record<string, unknown>): OrganizationTypeOption {
  return {
    id: json['id'] != null ? String(json['id']) : '',
    name: typeof json['name'] === 'string' ? json['name'] : '',
    displayName: typeof json['display_name'] === 'string' ? json['display_name'] : '',
    description: typeof json['description'] === 'string' ? json['description'] : null,
    icon: typeof json['icon'] === 'string' ? json['icon'] : null,
  };
}

export function parseMineSummary(json: Record<string, unknown>): OrganizationMineSummary {
  return {
    organizationCount:
      typeof json['organization_count'] === 'number'
        ? json['organization_count']
        : Number(json['organization_count']) || 0,
    collectiveBeneficiaries:
      typeof json['collective_beneficiaries'] === 'number'
        ? json['collective_beneficiaries']
        : Number(json['collective_beneficiaries']) || 0,
  };
}

export function parseOrganization(json: Record<string, unknown>): Organization {
  const countryField = json['country'];
  let countryName = '';
  let countryId: string | null = null;
  if (countryField && typeof countryField === 'object' && !Array.isArray(countryField)) {
    const c = countryField as Record<string, unknown>;
    countryId = c['id'] != null ? String(c['id']) : null;
    countryName =
      (typeof c['name'] === 'string' && c['name']) ||
      (typeof c['iso_code2'] === 'string' && c['iso_code2']) ||
      '';
  } else if (typeof countryField === 'string') {
    countryName = countryField;
  }

  const dc = json['default_currency'];
  let defaultCurrencyId: string | null = null;
  if (dc && typeof dc === 'object' && !Array.isArray(dc)) {
    defaultCurrencyId =
      (dc as Record<string, unknown>)['id'] != null
        ? String((dc as Record<string, unknown>)['id'])
        : null;
  }

  return {
    id: json['id'] != null ? String(json['id']) : '',
    name: typeof json['name'] === 'string' ? json['name'] : '',
    typeId: json['type'] != null ? String(json['type']) : '',
    typeDisplayName:
      typeof json['type_display_name'] === 'string' ? json['type_display_name'] : null,
    email: typeof json['email'] === 'string' ? json['email'] : '',
    address: typeof json['address'] === 'string' ? json['address'] : '',
    city: typeof json['city'] === 'string' ? json['city'] : '',
    postalCode: typeof json['postal_code'] === 'string' ? json['postal_code'] : '',
    country: countryName,
    countryId,
    defaultCurrencyId,
    description: typeof json['description'] === 'string' ? json['description'] : null,
    phone: typeof json['phone'] === 'string' ? json['phone'] : null,
    website: typeof json['website'] === 'string' ? json['website'] : null,
    logoUrl: typeof json['logo'] === 'string' ? json['logo'] : null,
    verificationStatus: parseChoiceEnum(json['verification_status']),
    rejectionReason: typeof json['rejection_reason'] === 'string' ? json['rejection_reason'] : null,
    businessLicenseNumber:
      typeof json['business_license_number'] === 'string' ? json['business_license_number'] : null,
    taxId: typeof json['tax_id'] === 'string' ? json['tax_id'] : null,
    isActive: typeof json['is_active'] === 'boolean' ? json['is_active'] : null,
    acceptsBookings:
      typeof json['accepts_bookings'] === 'boolean' ? json['accepts_bookings'] : null,
    requireClientName: json['require_client_name'] === true,
    kybSubmittedAt: typeof json['kyb_submitted_at'] === 'string' ? json['kyb_submitted_at'] : null,
    myMembershipRole: parseChoiceEnum(json['my_membership_role']),
    latitude: parseDouble(json['latitude']),
    longitude: parseDouble(json['longitude']),
    platformFees: parseOrganizationPlatformFees(json['platform_fees']),
  };
}

export function parseOrganizationPlatformFees(raw: unknown): OrganizationPlatformFees | null {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    return null;
  }
  const json = raw as Record<string, unknown>;
  return {
    platformFeeRate:
      json['platform_fee_rate'] != null ? String(json['platform_fee_rate']) : '1.00',
    platformFeeSource: parseChoiceEnum(json['platform_fee_source']),
    platformFeePayer: parseChoiceEnum(json['platform_fee_payer']),
    hasOrganizationOverride: json['has_organization_override'] === true,
    globalPlatformFeeRate:
      json['global_platform_fee_rate'] != null
        ? String(json['global_platform_fee_rate'])
        : '1.00',
    organizationPlatformFeeRate:
      json['organization_platform_fee_rate'] != null
        ? String(json['organization_platform_fee_rate'])
        : null,
    note: typeof json['note'] === 'string' ? json['note'] : null,
  };
}

export function parseTeamMember(json: Record<string, unknown>): TeamMember {
  return {
    id: json['id'] != null ? String(json['id']) : '',
    email: typeof json['email'] === 'string' ? json['email'] : '',
    firstName: typeof json['first_name'] === 'string' ? json['first_name'] : null,
    lastName: typeof json['last_name'] === 'string' ? json['last_name'] : null,
    phone: typeof json['phone'] === 'string' ? json['phone'] : null,
    role: parseChoiceEnum(json['role']),
    membershipRole: parseChoiceEnum(json['membership_role']),
  };
}

export function teamMemberDisplayName(m: TeamMember): string {
  const fn = m.firstName?.trim() ?? '';
  const ln = m.lastName?.trim() ?? '';
  if (!fn && !ln) {
    return m.email;
  }
  return `${fn} ${ln}`.trim();
}

export function parseOrganizationAnalytics(json: Record<string, unknown>): OrganizationAnalytics {
  return {
    organizationId: json['organization_id'] != null ? String(json['organization_id']) : '',
    totalBookings:
      typeof json['total_bookings'] === 'number'
        ? json['total_bookings']
        : Number(json['total_bookings']) || 0,
    confirmedBookings:
      typeof json['confirmed_bookings'] === 'number'
        ? json['confirmed_bookings']
        : Number(json['confirmed_bookings']) || 0,
    completedBookings:
      typeof json['completed_bookings'] === 'number'
        ? json['completed_bookings']
        : Number(json['completed_bookings']) || 0,
    cancelledBookings:
      typeof json['cancelled_bookings'] === 'number'
        ? json['cancelled_bookings']
        : Number(json['cancelled_bookings']) || 0,
    revenue: json['revenue'] != null ? String(json['revenue']) : '0',
    grossRevenue:
      json['gross_revenue'] != null ? String(json['gross_revenue']) : null,
    platformFees:
      json['platform_fees'] != null ? String(json['platform_fees']) : null,
    netRevenue: json['net_revenue'] != null ? String(json['net_revenue']) : null,
    currency: typeof json['currency'] === 'string' ? json['currency'] : null,
  };
}

export function isOrgVerified(org: Organization): boolean {
  return org.verificationStatus?.value === 'V';
}
