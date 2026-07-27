import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';

import { ApiPaths, DEFAULT_PAGE_SIZE } from '@/core/constants/api-paths';
import { mapHttpError } from '@/core/http/api-error';
import { PaginatedResponse, parsePaginatedResponse, toPageQuery } from '@/core/http/pagination';
import { LocaleService } from '@/core/i18n/locale.service';
import { ChoiceEnum, parseChoiceEnum } from '@/models/choice-enum';
import { environment } from '../../../environments/environment';

export interface StaffListParams {
  page?: number;
  pageSize?: number;
  search?: string;
  ordering?: string;
}

export interface StaffUserRow {
  id: string;
  email: string;
  username: string;
  firstName: string;
  lastName: string;
  phone: string;
  role: ChoiceEnum | null;
  verificationStatus: ChoiceEnum | null;
  isTrusted: boolean;
  rejectionReason: string;
  idDocumentUrl: string | null;
  selfieDocumentUrl: string | null;
  verifiedAt: string | null;
  createdAt: string | null;
  updatedAt: string | null;
}

export interface StaffWalletBalance {
  currencyCode: string;
  balance: string;
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

export interface StaffSubCategoryRow {
  id: string;
  name: string;
  categoryId: string;
  categoryName: string;
  description: string;
  isActive: boolean;
  sortOrder: number;
}

export interface StaffFeatureRow {
  id: string;
  name: string;
  featureType: ChoiceEnum | null;
  description: string;
  icon: string;
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

export interface StaffOverview {
  queues: {
    pendingKyc: number;
    pendingKyb: number;
    suspendedOrgs: number;
    rejectedKyc: number;
    rejectedKyb: number;
  };
  bookingsLast14Days: { date: string; count: number }[];
  paymentsLast14Days: { date: string; count: number; succeededAmount: string }[];
  feesByCurrency: {
    currency: string;
    totalAccrued: string;
    totalReversed: string;
    netFees: string;
  }[];
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

function parseStaffUser(json: Record<string, unknown>): StaffUserRow {
  return {
    id: json['id'] != null ? String(json['id']) : '',
    email: typeof json['email'] === 'string' ? json['email'] : '',
    username: typeof json['username'] === 'string' ? json['username'] : '',
    firstName: typeof json['first_name'] === 'string' ? json['first_name'] : '',
    lastName: typeof json['last_name'] === 'string' ? json['last_name'] : '',
    phone: typeof json['phone'] === 'string' ? json['phone'] : '',
    role: parseChoiceEnum(json['role']),
    verificationStatus: parseChoiceEnum(json['verification_status']),
    isTrusted: Boolean(json['is_trusted']),
    rejectionReason: typeof json['rejection_reason'] === 'string' ? json['rejection_reason'] : '',
    idDocumentUrl: typeof json['id_document_url'] === 'string' ? json['id_document_url'] : null,
    selfieDocumentUrl:
      typeof json['selfie_document_url'] === 'string' ? json['selfie_document_url'] : null,
    verifiedAt: typeof json['verified_at'] === 'string' ? json['verified_at'] : null,
    createdAt: typeof json['created_at'] === 'string' ? json['created_at'] : null,
    updatedAt: typeof json['updated_at'] === 'string' ? json['updated_at'] : null,
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

function parseStaffSubCategory(json: Record<string, unknown>): StaffSubCategoryRow {
  return {
    id: json['id'] != null ? String(json['id']) : '',
    name: typeof json['name'] === 'string' ? json['name'] : '',
    categoryId: json['category'] != null ? String(json['category']) : '',
    categoryName: typeof json['category_name'] === 'string' ? json['category_name'] : '',
    description: typeof json['description'] === 'string' ? json['description'] : '',
    isActive: Boolean(json['is_active']),
    sortOrder: typeof json['sort_order'] === 'number' ? json['sort_order'] : 0,
  };
}

function parseStaffFeature(json: Record<string, unknown>): StaffFeatureRow {
  return {
    id: json['id'] != null ? String(json['id']) : '',
    name: typeof json['name'] === 'string' ? json['name'] : '',
    featureType: parseChoiceEnum(json['feature_type']),
    description: typeof json['description'] === 'string' ? json['description'] : '',
    icon: typeof json['icon'] === 'string' ? json['icon'] : '',
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

function parseOverview(json: Record<string, unknown>): StaffOverview {
  const queues = (json['queues'] as Record<string, unknown>) ?? {};
  const bookings = Array.isArray(json['bookings_last_14_days'])
    ? json['bookings_last_14_days']
    : [];
  const payments = Array.isArray(json['payments_last_14_days'])
    ? json['payments_last_14_days']
    : [];
  const fees = Array.isArray(json['fees_by_currency']) ? json['fees_by_currency'] : [];
  return {
    queues: {
      pendingKyc: Number(queues['pending_kyc'] ?? 0),
      pendingKyb: Number(queues['pending_kyb'] ?? 0),
      suspendedOrgs: Number(queues['suspended_orgs'] ?? 0),
      rejectedKyc: Number(queues['rejected_kyc'] ?? 0),
      rejectedKyb: Number(queues['rejected_kyb'] ?? 0),
    },
    bookingsLast14Days: bookings.map((row) => {
      const r = row as Record<string, unknown>;
      return {
        date: typeof r['date'] === 'string' ? r['date'] : '',
        count: Number(r['count'] ?? 0),
      };
    }),
    paymentsLast14Days: payments.map((row) => {
      const r = row as Record<string, unknown>;
      return {
        date: typeof r['date'] === 'string' ? r['date'] : '',
        count: Number(r['count'] ?? 0),
        succeededAmount:
          r['succeeded_amount'] != null ? String(r['succeeded_amount']) : '0.00',
      };
    }),
    feesByCurrency: fees.map((row) => {
      const r = row as Record<string, unknown>;
      return {
        currency: typeof r['currency'] === 'string' ? r['currency'] : '',
        totalAccrued: r['total_accrued'] != null ? String(r['total_accrued']) : '0',
        totalReversed: r['total_reversed'] != null ? String(r['total_reversed']) : '0',
        netFees: r['net_fees'] != null ? String(r['net_fees']) : '0',
      };
    }),
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

  private baseParams(params: StaffListParams = {}): HttpParams {
    let httpParams = new HttpParams({
      fromObject: toPageQuery({
        page: params.page ?? 1,
        pageSize: params.pageSize ?? DEFAULT_PAGE_SIZE,
      }),
    });
    if (params.search?.trim()) {
      httpParams = httpParams.set('search', params.search.trim());
    }
    if (params.ordering?.trim()) {
      httpParams = httpParams.set('ordering', params.ordering.trim());
    }
    return httpParams;
  }

  async getOverview(): Promise<StaffOverview> {
    try {
      const data = await firstValueFrom(
        this.http.get<Record<string, unknown>>(this.url(ApiPaths.staffOverview)),
      );
      return parseOverview(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async listUsers(
    params: StaffListParams & { verificationStatus?: string } = {},
  ): Promise<PaginatedResponse<StaffUserRow>> {
    try {
      let httpParams = this.baseParams(params);
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

  async getUser(id: string): Promise<StaffUserRow> {
    try {
      const data = await firstValueFrom(
        this.http.get<Record<string, unknown>>(this.url(ApiPaths.staffUser(id))),
      );
      return parseStaffUser(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async getUserWallet(id: string): Promise<StaffWalletBalance[]> {
    try {
      const data = await firstValueFrom(
        this.http.get<{ balances?: Record<string, unknown>[] }>(
          this.url(ApiPaths.staffUserWallet(id)),
        ),
      );
      return (data.balances ?? []).map((row) => ({
        currencyCode: typeof row['currency_code'] === 'string' ? row['currency_code'] : '',
        balance: row['balance'] != null ? String(row['balance']) : '0',
      }));
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async creditUserWallet(
    id: string,
    body: { amount: string; currency_code: string; note?: string },
  ): Promise<void> {
    try {
      await firstValueFrom(
        this.http.post(this.url(ApiPaths.staffUserWalletCredit(id)), body),
      );
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async debitUserWallet(
    id: string,
    body: { amount: string; currency_code: string; note: string },
  ): Promise<void> {
    try {
      await firstValueFrom(
        this.http.post(this.url(ApiPaths.staffUserWalletDebit(id)), body),
      );
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async debitOrgRevenue(
    id: string,
    body: { amount: string; currency_code: string; note: string },
  ): Promise<void> {
    try {
      await firstValueFrom(
        this.http.post(this.url(ApiPaths.staffOrgRevenueDebit(id)), body),
      );
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
    params: StaffListParams & { verificationStatus?: string } = {},
  ): Promise<PaginatedResponse<StaffOrgRow>> {
    try {
      let httpParams = this.baseParams(params);
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

  async suspendOrganization(id: string): Promise<StaffOrgRow> {
    try {
      const data = await firstValueFrom(
        this.http.post<Record<string, unknown>>(
          this.url(ApiPaths.staffOrganizationSuspend(id)),
          {},
        ),
      );
      return parseStaffOrg(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async unsuspendOrganization(id: string): Promise<StaffOrgRow> {
    try {
      const data = await firstValueFrom(
        this.http.post<Record<string, unknown>>(
          this.url(ApiPaths.staffOrganizationUnsuspend(id)),
          {},
        ),
      );
      return parseStaffOrg(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async listCategories(params: StaffListParams = {}): Promise<PaginatedResponse<StaffCategoryRow>> {
    try {
      const data = await firstValueFrom(
        this.http.get<unknown>(this.url(ApiPaths.staffTaxonomyCategories), {
          params: this.baseParams(params),
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

  async listSubcategories(
    params: StaffListParams & { category?: string } = {},
  ): Promise<PaginatedResponse<StaffSubCategoryRow>> {
    try {
      let httpParams = this.baseParams(params);
      if (params.category) {
        httpParams = httpParams.set('category', params.category);
      }
      const data = await firstValueFrom(
        this.http.get<unknown>(this.url(ApiPaths.staffTaxonomySubcategories), {
          params: httpParams,
        }),
      );
      return parsePaginatedResponse(data, parseStaffSubCategory);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async createSubcategory(payload: {
    name: string;
    category: string;
    description?: string;
    is_active?: boolean;
    sort_order?: number;
  }): Promise<StaffSubCategoryRow> {
    try {
      const data = await firstValueFrom(
        this.http.post<Record<string, unknown>>(
          this.url(ApiPaths.staffTaxonomySubcategories),
          payload,
        ),
      );
      return parseStaffSubCategory(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async patchSubcategory(
    id: string,
    payload: Partial<{
      name: string;
      category: string;
      description: string;
      is_active: boolean;
      sort_order: number;
    }>,
  ): Promise<StaffSubCategoryRow> {
    try {
      const data = await firstValueFrom(
        this.http.patch<Record<string, unknown>>(
          this.url(ApiPaths.staffTaxonomySubcategory(id)),
          payload,
        ),
      );
      return parseStaffSubCategory(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async listFeatures(params: StaffListParams = {}): Promise<PaginatedResponse<StaffFeatureRow>> {
    try {
      const data = await firstValueFrom(
        this.http.get<unknown>(this.url(ApiPaths.staffTaxonomyFeatures), {
          params: this.baseParams(params),
        }),
      );
      return parsePaginatedResponse(data, parseStaffFeature);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async createFeature(payload: {
    name: string;
    feature_type: string;
    description?: string;
    icon?: string;
  }): Promise<StaffFeatureRow> {
    try {
      const data = await firstValueFrom(
        this.http.post<Record<string, unknown>>(this.url(ApiPaths.staffTaxonomyFeatures), payload),
      );
      return parseStaffFeature(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async patchFeature(
    id: string,
    payload: Partial<{
      name: string;
      feature_type: string;
      description: string;
      icon: string;
    }>,
  ): Promise<StaffFeatureRow> {
    try {
      const data = await firstValueFrom(
        this.http.patch<Record<string, unknown>>(
          this.url(ApiPaths.staffTaxonomyFeature(id)),
          payload,
        ),
      );
      return parseStaffFeature(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async listPayments(
    params: StaffListParams & { status?: string; provider?: string } = {},
  ): Promise<PaginatedResponse<StaffPaymentRow>> {
    try {
      let httpParams = this.baseParams(params);
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

  async getPlatformSettings(): Promise<{
    platformFeeRate: string;
    userInscriptionFeeUsd: string;
    businessAnnualFeeUsd: string;
    settlementMinimumUsd: string;
  }> {
    try {
      const data = await firstValueFrom(
        this.http.get<Record<string, unknown>>(this.url(ApiPaths.staffPlatformSettings)),
      );
      return {
        platformFeeRate:
          data['platform_fee_rate'] != null ? String(data['platform_fee_rate']) : '1.00',
        userInscriptionFeeUsd:
          data['user_inscription_fee_usd'] != null
            ? String(data['user_inscription_fee_usd'])
            : '5.00',
        businessAnnualFeeUsd:
          data['business_annual_fee_usd'] != null
            ? String(data['business_annual_fee_usd'])
            : '15.00',
        settlementMinimumUsd:
          data['settlement_minimum_usd'] != null
            ? String(data['settlement_minimum_usd'])
            : '10.00',
      };
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async patchPlatformSettings(body: {
    platformFeeRate?: string;
    userInscriptionFeeUsd?: string;
    businessAnnualFeeUsd?: string;
    settlementMinimumUsd?: string;
  }): Promise<{
    platformFeeRate: string;
    userInscriptionFeeUsd: string;
    businessAnnualFeeUsd: string;
    settlementMinimumUsd: string;
  }> {
    try {
      const payload: Record<string, string> = {};
      if (body.platformFeeRate != null) {
        payload['platform_fee_rate'] = body.platformFeeRate;
      }
      if (body.userInscriptionFeeUsd != null) {
        payload['user_inscription_fee_usd'] = body.userInscriptionFeeUsd;
      }
      if (body.businessAnnualFeeUsd != null) {
        payload['business_annual_fee_usd'] = body.businessAnnualFeeUsd;
      }
      if (body.settlementMinimumUsd != null) {
        payload['settlement_minimum_usd'] = body.settlementMinimumUsd;
      }
      const data = await firstValueFrom(
        this.http.patch<Record<string, unknown>>(
          this.url(ApiPaths.staffPlatformSettings),
          payload,
        ),
      );
      return {
        platformFeeRate:
          data['platform_fee_rate'] != null
            ? String(data['platform_fee_rate'])
            : body.platformFeeRate || '1.00',
        userInscriptionFeeUsd:
          data['user_inscription_fee_usd'] != null
            ? String(data['user_inscription_fee_usd'])
            : body.userInscriptionFeeUsd || '5.00',
        businessAnnualFeeUsd:
          data['business_annual_fee_usd'] != null
            ? String(data['business_annual_fee_usd'])
            : body.businessAnnualFeeUsd || '15.00',
        settlementMinimumUsd:
          data['settlement_minimum_usd'] != null
            ? String(data['settlement_minimum_usd'])
            : body.settlementMinimumUsd || '10.00',
      };
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async listSettlements(params: { status?: string } = {}): Promise<Array<Record<string, unknown>>> {
    try {
      let httpParams = new HttpParams();
      if (params.status) {
        httpParams = httpParams.set('status', params.status);
      }
      const data = await firstValueFrom(
        this.http.get<unknown>(this.url(ApiPaths.staffSettlements), { params: httpParams }),
      );
      if (Array.isArray(data)) {
        return data as Array<Record<string, unknown>>;
      }
      if (data && typeof data === 'object' && Array.isArray((data as { results?: unknown }).results)) {
        return (data as { results: Array<Record<string, unknown>> }).results;
      }
      return [];
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async completeSettlement(
    id: string,
    form: FormData,
  ): Promise<Record<string, unknown>> {
    try {
      return await firstValueFrom(
        this.http.post<Record<string, unknown>>(
          this.url(ApiPaths.staffSettlementComplete(id)),
          form,
        ),
      );
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async rejectSettlement(id: string, staffNote: string): Promise<Record<string, unknown>> {
    try {
      return await firstValueFrom(
        this.http.post<Record<string, unknown>>(this.url(ApiPaths.staffSettlementReject(id)), {
          staff_note: staffNote,
        }),
      );
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async createFxRate(body: {
    from_currency_code?: string;
    to_currency_code: string;
    rate: string;
    effective_at: string;
  }): Promise<Record<string, unknown>> {
    try {
      return await firstValueFrom(
        this.http.post<Record<string, unknown>>(this.url(ApiPaths.staffFxRates), body),
      );
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async listFxRates(): Promise<Array<Record<string, unknown>>> {
    try {
      const data = await firstValueFrom(this.http.get<unknown>(this.url(ApiPaths.staffFxRates)));
      if (Array.isArray(data)) {
        return data as Array<Record<string, unknown>>;
      }
      if (data && typeof data === 'object' && Array.isArray((data as { results?: unknown }).results)) {
        return (data as { results: Array<Record<string, unknown>> }).results;
      }
      return [];
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async listFeeEntries(
    params: StaffListParams & { organization?: string } = {},
  ): Promise<PaginatedResponse<StaffFeeEntryRow>> {
    try {
      let httpParams = this.baseParams(params);
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

  async listCategoryFees(
    params: StaffListParams = {},
  ): Promise<PaginatedResponse<StaffCategoryFeeRow>> {
    try {
      const data = await firstValueFrom(
        this.http.get<unknown>(this.url(ApiPaths.staffFeeCategories), {
          params: this.baseParams(params),
        }),
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
