import { ChoiceEnum, choiceEnumToJson, parseChoiceEnum } from './choice-enum';

/** One row from profile `organization_memberships` (DRF). */
export interface OrganizationMembership {
  id: string;
  organizationId: string;
  organizationName: string | null;
  role: ChoiceEnum;
}

export function parseOrganizationMembership(json: Record<string, unknown>): OrganizationMembership {
  const role = parseChoiceEnum(json['role']) ?? { value: '', title: '' };
  return {
    id: json['id'] != null ? String(json['id']) : '',
    organizationId: json['organization'] != null ? String(json['organization']) : '',
    organizationName: typeof json['organization_name'] === 'string' ? json['organization_name'] : null,
    role,
  };
}

export function organizationMembershipToJson(
  membership: OrganizationMembership,
): Record<string, unknown> {
  return {
    id: membership.id,
    organization: membership.organizationId,
    organization_name: membership.organizationName,
    role: choiceEnumToJson(membership.role),
  };
}
