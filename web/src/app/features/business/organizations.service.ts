import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';

import { ApiPaths } from '@/core/constants/api-paths';
import { mapHttpError } from '@/core/http/api-error';
import { parseJsonList } from '@/core/http/pagination';
import { LocaleService } from '@/core/i18n/locale.service';
import {
  CountryBrief,
  Organization,
  OrganizationAnalytics,
  OrganizationMineSummary,
  OrganizationTypeOption,
  TeamMember,
  parseCountryBrief,
  parseMineSummary,
  parseOrganization,
  parseOrganizationAnalytics,
  parseOrganizationType,
  parseTeamMember,
} from '@/models/organization';
import { environment } from '../../../environments/environment';

export interface OrganizationCreatePayload {
  typeId: string;
  name: string;
  email: string;
  address: string;
  city: string;
  postalCode: string;
  countryId: string;
  logo: File;
  phone?: string;
  description?: string;
  website?: string;
  requireClientName?: boolean;
}

export interface OrganizationUpdatePayload {
  name?: string;
  description?: string;
  phone?: string;
  email?: string;
  website?: string;
  requireClientName?: boolean;
  acceptedLocationTypes?: string[];
  countryId?: string;
  defaultCurrencyId?: string;
  primaryAddress?: string;
  primaryCity?: string;
  primaryPostalCode?: string;
  primaryCountryId?: string;
  primaryLatitude?: number;
  primaryLongitude?: number;
  logo?: File;
}

@Injectable({ providedIn: 'root' })
export class OrganizationsService {
  private readonly http = inject(HttpClient);
  private readonly locale = inject(LocaleService);

  private url(path: string): string {
    return `${environment.apiBaseUrl}${path}`;
  }

  private mapError(error: unknown) {
    return mapHttpError(error, {
      unexpected: this.locale.t('errors.unexpected'),
      requestFailed: this.locale.t('errors.requestFailed'),
      network: this.locale.t('errors.network'),
    });
  }

  async listMine(): Promise<Organization[]> {
    try {
      const data = await firstValueFrom(this.http.get<unknown>(this.url(ApiPaths.organizations)));
      return parseJsonList(data, parseOrganization);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async mineSummary(): Promise<OrganizationMineSummary> {
    try {
      const data = await firstValueFrom(
        this.http.get<Record<string, unknown>>(this.url(ApiPaths.organizationsMineSummary)),
      );
      return parseMineSummary(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async getById(id: string): Promise<Organization> {
    try {
      const data = await firstValueFrom(
        this.http.get<Record<string, unknown>>(this.url(ApiPaths.organization(id))),
      );
      return parseOrganization(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async create(payload: OrganizationCreatePayload): Promise<Organization> {
    const form = new FormData();
    form.append('type', payload.typeId);
    form.append('name', payload.name);
    form.append('email', payload.email);
    form.append('address', payload.address);
    form.append('city', payload.city);
    form.append('postal_code', payload.postalCode);
    form.append('country', payload.countryId);
    form.append('logo', payload.logo, payload.logo.name);
    if (payload.phone) {
      form.append('phone', payload.phone);
    }
    if (payload.description) {
      form.append('description', payload.description);
    }
    if (payload.website) {
      form.append('website', payload.website);
    }
    try {
      const data = await firstValueFrom(
        this.http.post<Record<string, unknown>>(this.url(ApiPaths.organizations), form),
      );
      return parseOrganization(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async update(id: string, payload: OrganizationUpdatePayload): Promise<Organization> {
    try {
      if (payload.logo) {
        const form = new FormData();
        this.appendUpdateFields(form, payload);
        form.append('logo', payload.logo, payload.logo.name);
        const data = await firstValueFrom(
          this.http.patch<Record<string, unknown>>(this.url(ApiPaths.organization(id)), form),
        );
        return parseOrganization(data);
      }
      const body: Record<string, unknown> = {};
      if (payload.name != null) {
        body['name'] = payload.name;
      }
      if (payload.description != null) {
        body['description'] = payload.description;
      }
      if (payload.phone != null) {
        body['phone'] = payload.phone;
      }
      if (payload.email != null) {
        body['email'] = payload.email;
      }
      if (payload.website != null) {
        body['website'] = payload.website;
      }
      if (payload.requireClientName != null) {
        body['require_client_name'] = payload.requireClientName;
      }
      if (payload.acceptedLocationTypes != null) {
        body['accepted_location_types'] = payload.acceptedLocationTypes;
      }
      if (payload.countryId != null) {
        body['country'] = payload.countryId;
      }
      if (payload.defaultCurrencyId != null) {
        body['default_currency'] = payload.defaultCurrencyId;
      }
      if (payload.primaryAddress != null) {
        body['primary_address'] = payload.primaryAddress;
      }
      if (payload.primaryCity != null) {
        body['primary_city'] = payload.primaryCity;
      }
      if (payload.primaryPostalCode != null) {
        body['primary_postal_code'] = payload.primaryPostalCode;
      }
      if (payload.primaryCountryId != null) {
        body['primary_country'] = payload.primaryCountryId;
      }
      if (payload.primaryLatitude != null) {
        body['primary_latitude'] = payload.primaryLatitude;
      }
      if (payload.primaryLongitude != null) {
        body['primary_longitude'] = payload.primaryLongitude;
      }
      const data = await firstValueFrom(
        this.http.patch<Record<string, unknown>>(this.url(ApiPaths.organization(id)), body),
      );
      return parseOrganization(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async listCountries(): Promise<CountryBrief[]> {
    try {
      const data = await firstValueFrom(
        this.http.get<unknown>(this.url(ApiPaths.organizationCountries)),
      );
      return parseJsonList(data, parseCountryBrief);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async listTypes(): Promise<OrganizationTypeOption[]> {
    try {
      const data = await firstValueFrom(
        this.http.get<unknown>(this.url(ApiPaths.organizationTypes)),
      );
      return parseJsonList(data, parseOrganizationType);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async team(organizationId: string): Promise<TeamMember[]> {
    try {
      const data = await firstValueFrom(
        this.http.get<unknown>(this.url(ApiPaths.organizationTeam(organizationId))),
      );
      return parseJsonList(data, parseTeamMember);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async inviteTeamMember(
    organizationId: string,
    payload: { email: string; role: string },
  ): Promise<TeamMember | null> {
    try {
      const data = await firstValueFrom(
        this.http.post<Record<string, unknown>>(
          this.url(ApiPaths.organizationTeamInvite(organizationId)),
          payload,
        ),
      );
      return data['membership_role'] || data['first_name'] || data['user_id']
        ? parseTeamMember(data)
        : null;
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async updateTeamMemberRole(
    organizationId: string,
    membershipId: string,
    role: string,
  ): Promise<TeamMember> {
    try {
      const data = await firstValueFrom(
        this.http.patch<Record<string, unknown>>(
          this.url(ApiPaths.organizationTeamMember(organizationId, membershipId)),
          { role },
        ),
      );
      return parseTeamMember(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async removeTeamMember(organizationId: string, membershipId: string): Promise<void> {
    try {
      await firstValueFrom(
        this.http.delete<void>(
          this.url(ApiPaths.organizationTeamMember(organizationId, membershipId)),
        ),
      );
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async analytics(organizationId: string): Promise<OrganizationAnalytics> {
    try {
      const data = await firstValueFrom(
        this.http.get<Record<string, unknown>>(
          this.url(ApiPaths.organizationAnalytics(organizationId)),
        ),
      );
      return parseOrganizationAnalytics(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async submitVerification(
    organizationId: string,
    payload: {
      businessLicense: File;
      idDocument: File;
      businessLicenseNumber?: string;
      taxId?: string;
    },
  ): Promise<Organization> {
    const form = new FormData();
    form.append('business_license_document', payload.businessLicense);
    form.append('id_document', payload.idDocument);
    if (payload.businessLicenseNumber) {
      form.append('business_license_number', payload.businessLicenseNumber);
    }
    if (payload.taxId) {
      form.append('tax_id', payload.taxId);
    }
    try {
      const data = await firstValueFrom(
        this.http.post<Record<string, unknown>>(
          this.url(ApiPaths.organizationSubmitVerification(organizationId)),
          form,
        ),
      );
      return parseOrganization(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  private appendUpdateFields(form: FormData, payload: OrganizationUpdatePayload): void {
    if (payload.name != null) {
      form.append('name', payload.name);
    }
    if (payload.description != null) {
      form.append('description', payload.description);
    }
    if (payload.phone != null) {
      form.append('phone', payload.phone);
    }
    if (payload.email != null) {
      form.append('email', payload.email);
    }
    if (payload.website != null) {
      form.append('website', payload.website);
    }
    if (payload.requireClientName != null) {
      form.append('require_client_name', String(payload.requireClientName));
    }
    if (payload.acceptedLocationTypes != null) {
      form.append('accepted_location_types', JSON.stringify(payload.acceptedLocationTypes));
    }
    if (payload.countryId != null) {
      form.append('country', payload.countryId);
    }
    if (payload.defaultCurrencyId != null) {
      form.append('default_currency', payload.defaultCurrencyId);
    }
    if (payload.primaryAddress != null) {
      form.append('primary_address', payload.primaryAddress);
    }
    if (payload.primaryCity != null) {
      form.append('primary_city', payload.primaryCity);
    }
    if (payload.primaryPostalCode != null) {
      form.append('primary_postal_code', payload.primaryPostalCode);
    }
    if (payload.primaryCountryId != null) {
      form.append('primary_country', payload.primaryCountryId);
    }
    if (payload.primaryLatitude != null) {
      form.append('primary_latitude', String(payload.primaryLatitude));
    }
    if (payload.primaryLongitude != null) {
      form.append('primary_longitude', String(payload.primaryLongitude));
    }
  }
}
