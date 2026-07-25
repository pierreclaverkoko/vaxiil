import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';

import { ApiPaths } from '@/core/constants/api-paths';
import { mapHttpError } from '@/core/http/api-error';
import { LocaleService } from '@/core/i18n/locale.service';
import { withOptionalClientLocation } from '@/core/utils/client-location';
import { environment } from '../../../environments/environment';

export interface PaymentLinkResult {
  url: string | null;
  merchantReference: string | null;
  transactionId: string | null;
  amountCharged: string;
  walletApplied: string;
  fullyPaid: boolean;
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

  async createPaymentLink(
    bookingId: string,
    options: { applyWallet?: boolean; walletAmount?: string } = {},
  ): Promise<PaymentLinkResult> {
    try {
      const body: Record<string, unknown> = {};
      if (options.applyWallet) {
        body['apply_wallet'] = true;
      }
      if (options.walletAmount != null && options.walletAmount !== '') {
        body['wallet_amount'] = options.walletAmount;
      }
      const payload = await withOptionalClientLocation(body);
      const data = await firstValueFrom(
        this.http.post<Record<string, unknown>>(
          this.url(ApiPaths.bookingPaymentLink(bookingId)),
          payload,
        ),
      );
      return {
        url: typeof data['url'] === 'string' ? data['url'] : null,
        merchantReference:
          typeof data['merchant_reference'] === 'string' ? data['merchant_reference'] : null,
        transactionId:
          typeof data['transaction_id'] === 'string' ? data['transaction_id'] : null,
        amountCharged:
          typeof data['amount_charged'] === 'string' ? data['amount_charged'] : '',
        walletApplied:
          typeof data['wallet_applied'] === 'string' ? data['wallet_applied'] : '0',
        fullyPaid: data['fully_paid'] === true,
      };
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async createWalletTopUp(amount: string, currencyCode: string): Promise<{
    url: string | null;
    merchantReference: string | null;
  }> {
    try {
      const payload = await withOptionalClientLocation({
        amount,
        currency_code: currencyCode,
      });
      const data = await firstValueFrom(
        this.http.post<Record<string, unknown>>(
          this.url(ApiPaths.paymentWalletTopUp),
          payload,
        ),
      );
      return {
        url: typeof data['url'] === 'string' ? data['url'] : null,
        merchantReference:
          typeof data['merchant_reference'] === 'string' ? data['merchant_reference'] : null,
      };
    } catch (error) {
      throw this.mapError(error);
    }
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
