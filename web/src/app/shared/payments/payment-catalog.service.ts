import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { firstValueFrom } from 'rxjs';

import { environment } from '../../../environments/environment';
import type { ChoiceEnum } from '@/models/choice-enum';
import { parseChoiceEnum } from '@/models/choice-enum';

export type PaymentOperation =
  | 'collect'
  | 'refund'
  | 'wallet_fund'
  | 'payout'
  | 'settlement'
  | 'business_payout';

export type PaymentIdentifierType = 'phone' | 'email' | 'generic';

export interface PaymentMethodBrief {
  id: string;
  code: string;
  name: string;
  logoUrl: string | null;
  methodType: ChoiceEnum | null;
  connectorCode: string | null;
  countryCode: string | null;
  currencyCode: string | null;
  accountRegex: string | null;
  destinationFields: string[];
  identifierType: PaymentIdentifierType;
  accountPlaceholder: string;
  phoneCountryCodes: string[];
  supportedOperations: string[];
}

export interface PaymentOperationPayload {
  operation: PaymentOperation;
  method: PaymentMethodBrief | null;
  accountIdentifier?: string;
  accountName?: string;
  details?: Record<string, string>;
  amount?: string;
  currencyCode?: string;
  settlementAccountId?: string;
}

@Injectable({ providedIn: 'root' })
export class PaymentCatalogService {
  private readonly http = inject(HttpClient);

  private url(path: string): string {
    return `${environment.apiBaseUrl}${path}`;
  }

  async listMethods(opts: {
    q?: string;
    country?: string;
    methodType?: string;
    connector?: string;
    operation?: string;
  }): Promise<PaymentMethodBrief[]> {
    let params = new HttpParams();
    if (opts.q) params = params.set('q', opts.q);
    if (opts.country) params = params.set('country', opts.country);
    if (opts.methodType) params = params.set('method_type', opts.methodType);
    if (opts.connector) params = params.set('connector', opts.connector);
    const op =
      opts.operation === 'business_payout' ? 'settlement' : opts.operation;
    if (op) params = params.set('operation', op);

    const data = await firstValueFrom(
      this.http.get<unknown>(this.url('payments/methods/'), { params }),
    );
    const rows = Array.isArray(data) ? data : [];
    return rows
      .filter((r): r is Record<string, unknown> => !!r && typeof r === 'object')
      .map((r) => this.parseMethod(r));
  }

  parseMethod(r: Record<string, unknown>): PaymentMethodBrief {
    const connector =
      r['connector'] && typeof r['connector'] === 'object'
        ? (r['connector'] as Record<string, unknown>)
        : null;
    const fields = Array.isArray(r['destination_fields'])
      ? r['destination_fields'].map(String)
      : [];
    const ops = Array.isArray(r['supported_operations'])
      ? r['supported_operations'].map(String)
      : [];
    const phoneCodes = Array.isArray(r['phone_country_codes'])
      ? r['phone_country_codes'].map((c) => String(c).toUpperCase())
      : [];
    const rawType =
      typeof r['identifier_type'] === 'string'
        ? r['identifier_type'].toLowerCase()
        : '';
    const identifierType: PaymentIdentifierType =
      rawType === 'phone' || rawType === 'email' || rawType === 'generic'
        ? rawType
        : 'generic';
    return {
      id: String(r['id'] ?? ''),
      code: typeof r['code'] === 'string' ? r['code'] : '',
      name: typeof r['name'] === 'string' ? r['name'] : '',
      logoUrl: typeof r['logo_url'] === 'string' ? r['logo_url'] : null,
      methodType: parseChoiceEnum(r['method_type']),
      connectorCode:
        typeof r['connector_code'] === 'string'
          ? r['connector_code']
          : connector && typeof connector['code'] === 'string'
            ? connector['code']
            : null,
      countryCode: typeof r['country_code'] === 'string' ? r['country_code'] : null,
      currencyCode:
        typeof r['currency_code'] === 'string' ? r['currency_code'] : null,
      accountRegex:
        typeof r['account_regex'] === 'string' && r['account_regex']
          ? r['account_regex']
          : null,
      destinationFields: fields,
      identifierType,
      accountPlaceholder:
        typeof r['account_placeholder'] === 'string'
          ? r['account_placeholder']
          : '',
      phoneCountryCodes: phoneCodes,
      supportedOperations: ops,
    };
  }
}
