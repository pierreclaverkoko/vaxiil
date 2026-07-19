/** Lightweight org row from `GET /api/v1/organizations/discovery/`. */
export interface OrganizationDiscovery {
  id: string;
  name: string;
  description: string;
  city: string;
  logoUrl: string | null;
}

export function parseOrganizationDiscovery(json: Record<string, unknown>): OrganizationDiscovery {
  return {
    id: json['id'] != null ? String(json['id']) : '',
    name: typeof json['name'] === 'string' ? json['name'] : '',
    description: typeof json['description'] === 'string' ? json['description'] : '',
    city: typeof json['city'] === 'string' ? json['city'] : '',
    logoUrl: typeof json['logo'] === 'string' ? json['logo'] : null,
  };
}
