import { ChoiceEnum, parseChoiceEnum } from './choice-enum';

/** Country brief on a payment method (detail / list enrichment). */
export interface PaymentTransactionMethodCountry {
  id: string;
  name: string;
  isoCode2: string;
  flag: string;
}

/** Payment rail shown on a consumer transaction row. */
export interface PaymentTransactionMethod {
  id: string;
  code: string;
  name: string;
  logoUrl: string | null;
  methodType: ChoiceEnum | null;
  country: PaymentTransactionMethodCountry | null;
}

/** Consumer payment history row from `GET /payments/transactions/`. */
export interface PaymentTransactionItem {
  id: string;
  bookingId: string | null;
  providerCode: string;
  amount: string;
  currencyCode: string;
  kind: ChoiceEnum | null;
  status: ChoiceEnum | null;
  purpose: ChoiceEnum | null;
  clientReference: string;
  createdAt: string | null;
  updatedAt: string | null;
  paymentMethod: PaymentTransactionMethod | null;
  accountIdentifier: string;
  /** False for internal store-credit refunds (no PSP status to poll). */
  canRefreshStatus: boolean;
}

function parseMethodCountry(raw: unknown): PaymentTransactionMethodCountry | null {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    return null;
  }
  const json = raw as Record<string, unknown>;
  return {
    id: json['id'] != null ? String(json['id']) : '',
    name: typeof json['name'] === 'string' ? json['name'] : '',
    isoCode2: typeof json['iso_code2'] === 'string' ? json['iso_code2'] : '',
    flag: typeof json['flag'] === 'string' ? json['flag'] : '',
  };
}

export function parsePaymentTransactionMethod(
  raw: unknown,
): PaymentTransactionMethod | null {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    return null;
  }
  const json = raw as Record<string, unknown>;
  return {
    id: json['id'] != null ? String(json['id']) : '',
    code: typeof json['code'] === 'string' ? json['code'] : '',
    name: typeof json['name'] === 'string' ? json['name'] : '',
    logoUrl: typeof json['logo_url'] === 'string' ? json['logo_url'] : null,
    methodType: parseChoiceEnum(json['method_type']),
    country: parseMethodCountry(json['country']),
  };
}

export function parsePaymentTransactionItem(
  json: Record<string, unknown>,
): PaymentTransactionItem {
  return {
    id: json['id'] != null ? String(json['id']) : '',
    bookingId:
      json['booking'] != null
        ? String(json['booking'])
        : json['booking_id'] != null
          ? String(json['booking_id'])
          : null,
    providerCode: typeof json['provider_code'] === 'string' ? json['provider_code'] : '',
    amount: typeof json['amount'] === 'string' ? json['amount'] : String(json['amount'] ?? ''),
    currencyCode: typeof json['currency_code'] === 'string' ? json['currency_code'] : '',
    kind: parseChoiceEnum(json['kind']),
    status: parseChoiceEnum(json['status']),
    purpose: parseChoiceEnum(json['purpose']),
    clientReference:
      typeof json['client_reference'] === 'string' ? json['client_reference'] : '',
    createdAt: typeof json['created_at'] === 'string' ? json['created_at'] : null,
    updatedAt: typeof json['updated_at'] === 'string' ? json['updated_at'] : null,
    paymentMethod: parsePaymentTransactionMethod(json['payment_method']),
    accountIdentifier:
      typeof json['account_identifier'] === 'string' ? json['account_identifier'] : '',
    canRefreshStatus: json['can_refresh_status'] !== false,
  };
}

/** Extract bare status char from enriched detail (poll / legacy). */
export function statusCodeFromTransactionDetail(data: Record<string, unknown>): string {
  if (typeof data['status_code'] === 'string') {
    return data['status_code'];
  }
  const status = data['status'];
  if (typeof status === 'string') {
    return status;
  }
  if (status && typeof status === 'object' && !Array.isArray(status)) {
    const value = (status as Record<string, unknown>)['value'];
    if (typeof value === 'string') {
      return value;
    }
  }
  return '';
}
