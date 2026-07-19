import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';

import { ApiPaths, DEFAULT_PAGE_SIZE } from '@/core/constants/api-paths';
import { mapHttpError } from '@/core/http/api-error';
import { PaginatedResponse, parsePaginatedResponse, toPageQuery } from '@/core/http/pagination';
import { LocaleService } from '@/core/i18n/locale.service';
import { ChoiceEnum, parseChoiceEnum } from '@/models/choice-enum';
import { environment } from '../../../environments/environment';

export interface StaffUserRow {
  id: string;
  email: string;
  firstName: string;
  lastName: string;
  verificationStatus: ChoiceEnum | null;
  rejectionReason: string;
  idDocumentUrl: string | null;
  selfieDocumentUrl: string | null;
  verifiedAt: string | null;
}

export interface StaffOrgRow {
  id: string;
  name: string;
  email: string;
  typeName: string;
  verificationStatus: ChoiceEnum | null;
  rejectionReason: string;
  businessLicenseDocumentUrl: string | null;
  idDocumentUrl: string | null;
  kybSubmittedAt: string | null;
  verifiedAt: string | null;
}

export interface StaffCategoryRow {
  id: string;
  name: string;
  description: string;
  icon: string;
  isActive: boolean;
  sortOrder: number;
}

export interface StaffPaymentRow {
  id: string;
  bookingId: string;
  userEmail: string | null;
  providerCode: string;
  amount: string;
  currencyCode: string;
  status: ChoiceEnum | null;
  kind: ChoiceEnum | null;
  clientReference: string;
  createdAt: string | null;
}

function parseStaffUser(json: Record<string, unknown>): StaffUserRow {
  return {
    id: json['id'] != null ? String(json['id']) : '',
    email: typeof json['email'] === 'string' ? json['email'] : '',
    firstName: typeof json['first_name'] === 'string' ? json['first_name'] : '',
    lastName: typeof json['last_name'] === 'string' ? json['last_name'] : '',
    verificationStatus: parseChoiceEnum(json['verification_status']),
    rejectionReason: typeof json['rejection_reason'] === 'string' ? json['rejection_reason'] : '',
    idDocumentUrl: typeof json['id_document_url'] === 'string' ? json['id_document_url'] : null,
    selfieDocumentUrl:
      typeof json['selfie_document_url'] === 'string' ? json['selfie_document_url'] : null,
    verifiedAt: typeof json['verified_at'] === 'string' ? json['verified_at'] : null,
  };
}

function parseStaffOrg(json: Record<string, unknown>): StaffOrgRow {
  return {
    id: json['id'] != null ? String(json['id']) : '',
    name: typeof json['name'] === 'string' ? json['name'] : '',
    email: typeof json['email'] === 'string' ? json['email'] : '',
    typeName: typeof json['type_name'] === 'string' ? json['type_name'] : '',
    verificationStatus: parseChoiceEnum(json['verification_status']),
    rejectionReason: typeof json['rejection_reason'] === 'string' ? json['rejection_reason'] : '',
    businessLicenseDocumentUrl:
      typeof json['business_license_document_url'] === 'string'
        ? json['business_license_document_url']
        : null,
    idDocumentUrl: typeof json['id_document_url'] === 'string' ? json['id_document_url'] : null,
    kybSubmittedAt: typeof json['kyb_submitted_at'] === 'string' ? json['kyb_submitted_at'] : null,
    verifiedAt: typeof json['verified_at'] === 'string' ? json['verified_at'] : null,
  };
}

function parseStaffCategory(json: Record<string, unknown>): StaffCategoryRow {
  return {
    id: json['id'] != null ? String(json['id']) : '',
    name: typeof json['name'] === 'string' ? json['name'] : '',
    description: typeof json['description'] === 'string' ? json['description'] : '',
    icon: typeof json['icon'] === 'string' ? json['icon'] : '',
    isActive: Boolean(json['is_active']),
    sortOrder: typeof json['sort_order'] === 'number' ? json['sort_order'] : 0,
  };
}

function parseStaffPayment(json: Record<string, unknown>): StaffPaymentRow {
  return {
    id: json['id'] != null ? String(json['id']) : '',
    bookingId: json['booking'] != null ? String(json['booking']) : '',
    userEmail: typeof json['user_email'] === 'string' ? json['user_email'] : null,
    providerCode: typeof json['provider_code'] === 'string' ? json['provider_code'] : '',
    amount: typeof json['amount'] === 'string' ? json['amount'] : String(json['amount'] ?? ''),
    currencyCode: typeof json['currency_code'] === 'string' ? json['currency_code'] : '',
    status: parseChoiceEnum(json['status']),
    kind: parseChoiceEnum(json['kind']),
    clientReference: typeof json['client_reference'] === 'string' ? json['client_reference'] : '',
    createdAt: typeof json['created_at'] === 'string' ? json['created_at'] : null,
  };
}

@Injectable({ providedIn: 'root' })
export class StaffApiService {
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

  async listUsers(
    params: { page?: number; verificationStatus?: string } = {},
  ): Promise<PaginatedResponse<StaffUserRow>> {
    try {
      let httpParams = new HttpParams({
        fromObject: toPageQuery({ page: params.page ?? 1, pageSize: DEFAULT_PAGE_SIZE }),
      });
      if (params.verificationStatus) {
        httpParams = httpParams.set('verification_status', params.verificationStatus);
      }
      const data = await firstValueFrom(
        this.http.get<unknown>(this.url(ApiPaths.staffUsers), { params: httpParams }),
      );
      return parsePaginatedResponse(data, parseStaffUser);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async approveUser(id: string): Promise<StaffUserRow> {
    try {
      const data = await firstValueFrom(
        this.http.post<Record<string, unknown>>(this.url(ApiPaths.staffUserApprove(id)), {}),
      );
      return parseStaffUser(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async rejectUser(id: string, reason: string): Promise<StaffUserRow> {
    try {
      const data = await firstValueFrom(
        this.http.post<Record<string, unknown>>(this.url(ApiPaths.staffUserReject(id)), {
          reason,
        }),
      );
      return parseStaffUser(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async listOrganizations(
    params: { page?: number; verificationStatus?: string } = {},
  ): Promise<PaginatedResponse<StaffOrgRow>> {
    try {
      let httpParams = new HttpParams({
        fromObject: toPageQuery({ page: params.page ?? 1, pageSize: DEFAULT_PAGE_SIZE }),
      });
      if (params.verificationStatus) {
        httpParams = httpParams.set('verification_status', params.verificationStatus);
      }
      const data = await firstValueFrom(
        this.http.get<unknown>(this.url(ApiPaths.staffOrganizations), { params: httpParams }),
      );
      return parsePaginatedResponse(data, parseStaffOrg);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async approveOrganization(id: string): Promise<StaffOrgRow> {
    try {
      const data = await firstValueFrom(
        this.http.post<Record<string, unknown>>(
          this.url(ApiPaths.staffOrganizationApprove(id)),
          {},
        ),
      );
      return parseStaffOrg(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async rejectOrganization(id: string, reason: string): Promise<StaffOrgRow> {
    try {
      const data = await firstValueFrom(
        this.http.post<Record<string, unknown>>(this.url(ApiPaths.staffOrganizationReject(id)), {
          reason,
        }),
      );
      return parseStaffOrg(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async listCategories(page = 1): Promise<PaginatedResponse<StaffCategoryRow>> {
    try {
      const httpParams = new HttpParams({
        fromObject: toPageQuery({ page, pageSize: DEFAULT_PAGE_SIZE }),
      });
      const data = await firstValueFrom(
        this.http.get<unknown>(this.url(ApiPaths.staffTaxonomyCategories), {
          params: httpParams,
        }),
      );
      return parsePaginatedResponse(data, parseStaffCategory);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async createCategory(payload: {
    name: string;
    description?: string;
    icon?: string;
    is_active?: boolean;
    sort_order?: number;
  }): Promise<StaffCategoryRow> {
    try {
      const data = await firstValueFrom(
        this.http.post<Record<string, unknown>>(
          this.url(ApiPaths.staffTaxonomyCategories),
          payload,
        ),
      );
      return parseStaffCategory(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async patchCategory(
    id: string,
    payload: Partial<{
      name: string;
      description: string;
      icon: string;
      is_active: boolean;
      sort_order: number;
    }>,
  ): Promise<StaffCategoryRow> {
    try {
      const data = await firstValueFrom(
        this.http.patch<Record<string, unknown>>(
          this.url(ApiPaths.staffTaxonomyCategory(id)),
          payload,
        ),
      );
      return parseStaffCategory(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async listPayments(
    params: { page?: number; status?: string; provider?: string } = {},
  ): Promise<PaginatedResponse<StaffPaymentRow>> {
    try {
      let httpParams = new HttpParams({
        fromObject: toPageQuery({ page: params.page ?? 1, pageSize: DEFAULT_PAGE_SIZE }),
      });
      if (params.status) {
        httpParams = httpParams.set('status', params.status);
      }
      if (params.provider) {
        httpParams = httpParams.set('provider', params.provider);
      }
      const data = await firstValueFrom(
        this.http.get<unknown>(this.url(ApiPaths.staffPayments), { params: httpParams }),
      );
      return parsePaginatedResponse(data, parseStaffPayment);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async getPlatformSettings(): Promise<{ platformFeeRate: string }> {
    try {
      const data = await firstValueFrom(
        this.http.get<Record<string, unknown>>(this.url(ApiPaths.staffPlatformSettings)),
      );
      return {
        platformFeeRate:
          data['platform_fee_rate'] != null ? String(data['platform_fee_rate']) : '1.00',
      };
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async patchPlatformSettings(platformFeeRate: string): Promise<{ platformFeeRate: string }> {
    try {
      const data = await firstValueFrom(
        this.http.patch<Record<string, unknown>>(this.url(ApiPaths.staffPlatformSettings), {
          platform_fee_rate: platformFeeRate,
        }),
      );
      return {
        platformFeeRate:
          data['platform_fee_rate'] != null ? String(data['platform_fee_rate']) : platformFeeRate,
      };
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async listFeeEntries(
    params: { page?: number; organization?: string } = {},
  ): Promise<PaginatedResponse<StaffFeeEntryRow>> {
    try {
      let httpParams = new HttpParams({
        fromObject: toPageQuery({ page: params.page ?? 1, pageSize: DEFAULT_PAGE_SIZE }),
      });
      if (params.organization) {
        httpParams = httpParams.set('organization', params.organization);
      }
      const data = await firstValueFrom(
        this.http.get<unknown>(this.url(ApiPaths.staffFees), { params: httpParams }),
      );
      return parsePaginatedResponse(data, parseStaffFeeEntry);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async feeSummary(params: { dateFrom?: string; dateTo?: string } = {}): Promise<
    { currency: string; totalAccrued: string; totalReversed: string; netFees: string }[]
  > {
    try {
      let httpParams = new HttpParams();
      if (params.dateFrom) {
        httpParams = httpParams.set('date_from', params.dateFrom);
      }
      if (params.dateTo) {
        httpParams = httpParams.set('date_to', params.dateTo);
      }
      const data = await firstValueFrom(
        this.http.get<{ by_currency: Record<string, unknown>[] }>(
          this.url(ApiPaths.staffFeesSummary),
          { params: httpParams },
        ),
      );
      return (data.by_currency ?? []).map((row) => ({
        currency: typeof row['currency'] === 'string' ? row['currency'] : '',
        totalAccrued: row['total_accrued'] != null ? String(row['total_accrued']) : '0',
        totalReversed: row['total_reversed'] != null ? String(row['total_reversed']) : '0',
        netFees: row['net_fees'] != null ? String(row['net_fees']) : '0',
      }));
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async listCategoryFees(): Promise<PaginatedResponse<StaffCategoryFeeRow>> {
    try {
      const data = await firstValueFrom(
        this.http.get<unknown>(this.url(ApiPaths.staffFeeCategories)),
      );
      return parsePaginatedResponse(data, parseStaffCategoryFee);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async createCategoryFee(categoryId: string, rate: string): Promise<StaffCategoryFeeRow> {
    try {
      const data = await firstValueFrom(
        this.http.post<Record<string, unknown>>(this.url(ApiPaths.staffFeeCategories), {
          category: categoryId,
          rate,
        }),
      );
      return parseStaffCategoryFee(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async patchOrganizationFeeSettings(
    orgId: string,
    payload: {
      platform_fee_rate?: string | null;
      platform_fee_payer?: string;
      clear_rate_override?: boolean;
    },
  ): Promise<Record<string, unknown>> {
    try {
      return await firstValueFrom(
        this.http.patch<Record<string, unknown>>(
          this.url(ApiPaths.staffOrganizationFeeSettings(orgId)),
          payload,
        ),
      );
    } catch (error) {
      throw this.mapError(error);
    }
  }
}

export interface StaffFeeEntryRow {
  id: string;
  bookingId: string;
  organizationName: string;
  amount: string;
  currencyCode: string;
  rate: string;
  payer: ChoiceEnum | null;
  source: ChoiceEnum | null;
  status: ChoiceEnum | null;
  createdAt: string | null;
}

export interface StaffCategoryFeeRow {
  id: string;
  categoryId: string;
  categoryName: string;
  rate: string;
}

function parseStaffFeeEntry(json: Record<string, unknown>): StaffFeeEntryRow {
  return {
    id: json['id'] != null ? String(json['id']) : '',
    bookingId: json['booking'] != null ? String(json['booking']) : '',
    organizationName:
      typeof json['organization_name'] === 'string' ? json['organization_name'] : '',
    amount: json['amount'] != null ? String(json['amount']) : '0',
    currencyCode: typeof json['currency_code'] === 'string' ? json['currency_code'] : '',
    rate: json['rate'] != null ? String(json['rate']) : '0',
    payer: parseChoiceEnum(json['payer']),
    source: parseChoiceEnum(json['source']),
    status: parseChoiceEnum(json['status']),
    createdAt: typeof json['created_at'] === 'string' ? json['created_at'] : null,
  };
}

function parseStaffCategoryFee(json: Record<string, unknown>): StaffCategoryFeeRow {
  return {
    id: json['id'] != null ? String(json['id']) : '',
    categoryId: json['category'] != null ? String(json['category']) : '',
    categoryName: typeof json['category_name'] === 'string' ? json['category_name'] : '',
    rate: json['rate'] != null ? String(json['rate']) : '0',
  };
}
