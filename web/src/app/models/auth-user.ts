import { ChoiceEnum, choiceEnumToJson, parseChoiceEnum } from './choice-enum';
import {
  OrganizationMembership,
  organizationMembershipToJson,
  parseOrganizationMembership,
} from './organization-membership';

export interface AuthUser {
  id: string;
  email: string;
  username: string | null;
  firstName: string | null;
  lastName: string | null;
  phone: string | null;
  role: ChoiceEnum | null;
  organization: string | null;
  organizationName: string | null;
  organizationMemberships: OrganizationMembership[];
  trustAlias: string | null;
  avatarUrl: string | null;
  showRealName: boolean;
  showPhoneNumber: boolean;
  showEmail: boolean;
  dateOfBirth: string | null;
  sex: ChoiceEnum | null;
  age: number | null;
  verificationStatus: ChoiceEnum | null;
  verificationRejectionReason: string | null;
  verifiedAt: string | null;
  idDocumentUrl: string | null;
  selfieDocumentUrl: string | null;
  isStaff: boolean;
  twoFactorEnabled: boolean;
  emailVerified: boolean;
  needsEmailVerification: boolean;
  legal: AuthUserLegal | null;
}

export interface AuthUserLegal {
  termsVersion: string | null;
  termsDocumentId: string | null;
  privacyVersion: string | null;
  privacyDocumentId: string | null;
  acceptedTerms: boolean;
  acceptedPrivacy: boolean;
  needsAcceptance: boolean;
}

export function parseAuthUser(json: Record<string, unknown>): AuthUser {
  const rawMemberships = json['organization_memberships'];
  const memberships: OrganizationMembership[] = [];
  if (Array.isArray(rawMemberships)) {
    for (const e of rawMemberships) {
      if (e && typeof e === 'object' && !Array.isArray(e)) {
        memberships.push(parseOrganizationMembership(e as Record<string, unknown>));
      }
    }
  }

  return {
    id: json['id'] != null ? String(json['id']) : '',
    email: typeof json['email'] === 'string' ? json['email'] : '',
    username: typeof json['username'] === 'string' ? json['username'] : null,
    firstName: typeof json['first_name'] === 'string' ? json['first_name'] : null,
    lastName: typeof json['last_name'] === 'string' ? json['last_name'] : null,
    phone: typeof json['phone'] === 'string' ? json['phone'] : null,
    role: parseChoiceEnum(json['role']),
    organization: json['organization'] != null ? String(json['organization']) : null,
    organizationName:
      typeof json['organization_name'] === 'string' ? json['organization_name'] : null,
    organizationMemberships: memberships,
    trustAlias: typeof json['trust_alias'] === 'string' ? json['trust_alias'] : null,
    avatarUrl: typeof json['avatar'] === 'string' ? json['avatar'] : null,
    showRealName: Boolean(json['show_real_name']),
    showPhoneNumber: Boolean(json['show_phone_number']),
    showEmail: Boolean(json['show_email']),
    dateOfBirth: typeof json['date_of_birth'] === 'string' ? json['date_of_birth'] : null,
    sex: parseChoiceEnum(json['sex']),
    age: typeof json['age'] === 'number' ? json['age'] : null,
    verificationStatus: parseChoiceEnum(json['verification_status']),
    verificationRejectionReason:
      typeof json['rejection_reason'] === 'string' ? json['rejection_reason'] : null,
    verifiedAt: typeof json['verified_at'] === 'string' ? json['verified_at'] : null,
    idDocumentUrl:
      typeof json['id_document_url'] === 'string' ? json['id_document_url'] : null,
    selfieDocumentUrl:
      typeof json['selfie_document_url'] === 'string' ? json['selfie_document_url'] : null,
    isStaff: Boolean(json['is_staff']),
    twoFactorEnabled: json['two_factor_enabled'] !== false,
    emailVerified: json['email_verified'] !== false,
    needsEmailVerification: json['needs_email_verification'] === true,
    legal: parseAuthUserLegal(json['legal']),
  };
}

export function parseAuthUserLegal(raw: unknown): AuthUserLegal | null {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    return null;
  }
  const json = raw as Record<string, unknown>;
  return {
    termsVersion: typeof json['terms_version'] === 'string' ? json['terms_version'] : null,
    termsDocumentId:
      json['terms_document_id'] != null ? String(json['terms_document_id']) : null,
    privacyVersion:
      typeof json['privacy_version'] === 'string' ? json['privacy_version'] : null,
    privacyDocumentId:
      json['privacy_document_id'] != null ? String(json['privacy_document_id']) : null,
    acceptedTerms: json['accepted_terms'] === true,
    acceptedPrivacy: json['accepted_privacy'] === true,
    needsAcceptance: json['needs_acceptance'] === true,
  };
}

export function authUserDisplayName(user: AuthUser): string {
  const fn = user.firstName?.trim() ?? '';
  const ln = user.lastName?.trim() ?? '';
  if (!fn && !ln) {
    return user.email;
  }
  return `${fn} ${ln}`.trim();
}

export function authUserToJson(user: AuthUser): Record<string, unknown> {
  return {
    id: user.id,
    email: user.email,
    username: user.username,
    first_name: user.firstName,
    last_name: user.lastName,
    phone: user.phone,
    role: choiceEnumToJson(user.role),
    organization: user.organization,
    organization_name: user.organizationName,
    organization_memberships: user.organizationMemberships.map(organizationMembershipToJson),
    trust_alias: user.trustAlias,
    avatar: user.avatarUrl,
    show_real_name: user.showRealName,
    show_phone_number: user.showPhoneNumber,
    show_email: user.showEmail,
    date_of_birth: user.dateOfBirth,
    sex: choiceEnumToJson(user.sex),
    age: user.age,
    verification_status: choiceEnumToJson(user.verificationStatus),
    rejection_reason: user.verificationRejectionReason,
    verified_at: user.verifiedAt,
    id_document_url: user.idDocumentUrl,
    selfie_document_url: user.selfieDocumentUrl,
    is_staff: user.isStaff,
    two_factor_enabled: user.twoFactorEnabled,
    email_verified: user.emailVerified,
    needs_email_verification: user.needsEmailVerification,
    legal: user.legal
      ? {
          terms_version: user.legal.termsVersion,
          terms_document_id: user.legal.termsDocumentId,
          privacy_version: user.legal.privacyVersion,
          privacy_document_id: user.legal.privacyDocumentId,
          accepted_terms: user.legal.acceptedTerms,
          accepted_privacy: user.legal.acceptedPrivacy,
          needs_acceptance: user.legal.needsAcceptance,
        }
      : null,
  };
}
