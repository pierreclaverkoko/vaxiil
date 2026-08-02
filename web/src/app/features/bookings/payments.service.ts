import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';

import { ApiPaths } from '@/core/constants/api-paths';
import { mapHttpError } from '@/core/http/api-error';
import { LocaleService } from '@/core/i18n/locale.service';
import { withOptionalClientLocation } from '@/core/utils/client-location';
import { environment } from '../../../environments/environment';

export interface CollectPaymentResult {
  merchantReference: string | null;
  transactionId: string | null;
  amountCharged: string;
  walletApplied: string;
  fullyPaid: boolean;
  status: string | null;
  message: string;
}

export interface FundWalletResult {
  merchantReference: string | null;
  transactionId: string | null;
  amount: string;
  status: string | null;
  message: string;
}

export interface CollectDestination {
  paymentMethodId: string;
  accountIdentifier: string;
  accountName?: string;
  details?: Record<string, string>;
}

export interface RefundWalletBalance {
  currencyCode: string;
  balance: string;
}

export interface RefundWalletSummary {
  balances: RefundWalletBalance[];
  totalCredited: string;
}

export interface PaymentTransactionStatus {
  transactionId: string;
  clientReference: string;
  status: string;
  bookingId: string | null;
  amount: string;
}

/** @deprecated Use CollectPaymentResult */
export type PaymentLinkResult = CollectPaymentResult & { url?: string | null };

@Injectable({ providedIn: 'root' })
export class PaymentsService {
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

  async getWallet(): Promise<RefundWalletSummary> {
    try {
      const data = await firstValueFrom(
        this.http.get<Record<string, unknown>>(this.url(ApiPaths.paymentWallet)),
      );
      const rawBalances = Array.isArray(data['balances']) ? data['balances'] : [];
      return {
        balances: rawBalances
          .filter((row): row is Record<string, unknown> => !!row && typeof row === 'object')
          .map((row) => ({
            currencyCode: typeof row['currency_code'] === 'string' ? row['currency_code'] : '',
            balance: typeof row['balance'] === 'string' ? row['balance'] : '0',
          })),
        totalCredited:
          typeof data['total_credited'] === 'string' ? data['total_credited'] : '0',
      };
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async collectForBooking(
    bookingId: string,
    options: {
      applyWallet?: boolean;
      walletAmount?: string;
      destination?: CollectDestination | null;
    } = {},
  ): Promise<CollectPaymentResult> {
    try {
      const body: Record<string, unknown> = {};
      if (options.applyWallet) {
        body['apply_wallet'] = true;
      }
      if (options.walletAmount != null && options.walletAmount !== '') {
        body['wallet_amount'] = options.walletAmount;
      }
      const dest = options.destination;
      if (dest) {
        body['payment_method_id'] = dest.paymentMethodId;
        body['account_identifier'] = dest.accountIdentifier;
        if (dest.accountName) {
          body['account_name'] = dest.accountName;
        }
        if (dest.details && Object.keys(dest.details).length) {
          body['details'] = dest.details;
        }
      }
      const payload = await withOptionalClientLocation(body);
      const data = await firstValueFrom(
        this.http.post<Record<string, unknown>>(
          this.url(ApiPaths.bookingPaymentLink(bookingId)),
          payload,
        ),
      );
      return {
        merchantReference:
          typeof data['merchant_reference'] === 'string' ? data['merchant_reference'] : null,
        transactionId:
          typeof data['transaction_id'] === 'string' ? data['transaction_id'] : null,
        amountCharged:
          typeof data['amount_charged'] === 'string' ? data['amount_charged'] : '',
        walletApplied:
          typeof data['wallet_applied'] === 'string' ? data['wallet_applied'] : '0',
        fullyPaid: data['fully_paid'] === true,
        status: typeof data['status'] === 'string' ? data['status'] : null,
        message: typeof data['message'] === 'string' ? data['message'] : '',
      };
    } catch (error) {
      throw this.mapError(error);
    }
  }

  /** @deprecated Prefer collectForBooking */
  async createPaymentLink(
    bookingId: string,
    options: {
      applyWallet?: boolean;
      walletAmount?: string;
      destination?: CollectDestination | null;
    } = {},
  ): Promise<CollectPaymentResult> {
    return this.collectForBooking(bookingId, options);
  }

  async fundWallet(
    amount: string,
    currencyCode: string,
    destination: CollectDestination,
  ): Promise<FundWalletResult> {
    try {
      const payload = await withOptionalClientLocation({
        amount,
        currency_code: currencyCode,
        payment_method_id: destination.paymentMethodId,
        account_identifier: destination.accountIdentifier,
        account_name: destination.accountName || undefined,
        details: destination.details,
      });
      const data = await firstValueFrom(
        this.http.post<Record<string, unknown>>(
          this.url(ApiPaths.paymentWalletTopUp),
          payload,
        ),
      );
      return {
        merchantReference:
          typeof data['merchant_reference'] === 'string' ? data['merchant_reference'] : null,
        transactionId:
          typeof data['transaction_id'] === 'string' ? data['transaction_id'] : null,
        amount: typeof data['amount'] === 'string' ? data['amount'] : amount,
        status: typeof data['status'] === 'string' ? data['status'] : null,
        message: typeof data['message'] === 'string' ? data['message'] : '',
      };
    } catch (error) {
      throw this.mapError(error);
    }
  }

  /** @deprecated Prefer fundWallet with destination */
  async createWalletTopUp(
    amount: string,
    currencyCode: string,
    destination?: CollectDestination,
  ): Promise<FundWalletResult> {
    if (!destination) {
      throw this.mapError(new Error('payment method required'));
    }
    return this.fundWallet(amount, currencyCode, destination);
  }

  async getTransaction(clientReference: string): Promise<PaymentTransactionStatus> {
    try {
      const data = await firstValueFrom(
        this.http.get<Record<string, unknown>>(
          this.url(ApiPaths.paymentTransaction(clientReference)),
        ),
      );
      return {
        transactionId:
          typeof data['transaction_id'] === 'string' ? data['transaction_id'] : '',
        clientReference:
          typeof data['client_reference'] === 'string' ? data['client_reference'] : '',
        status: typeof data['status'] === 'string' ? data['status'] : '',
        bookingId: data['booking_id'] != null ? String(data['booking_id']) : null,
        amount: typeof data['amount'] === 'string' ? data['amount'] : '',
      };
    } catch (error) {
      throw this.mapError(error);
    }
  }
}
