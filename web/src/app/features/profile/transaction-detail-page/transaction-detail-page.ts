import { DatePipe } from '@angular/common';
import { Component, OnInit, inject, signal } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';

import { ApiError } from '@/core/http/api-error';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { PaymentsService } from '@/features/bookings/payments.service';
import { PaymentTransactionItem } from '@/models/payment-transaction';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ChoiceEnumChipComponent } from '@/shared/ui/choice-enum-chip/choice-enum-chip';
import { EmptyStateComponent } from '@/shared/ui/empty-state/empty-state';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';

@Component({
  selector: 'app-transaction-detail-page',
  standalone: true,
  imports: [
    ButtonComponent,
    ChoiceEnumChipComponent,
    DatePipe,
    EmptyStateComponent,
    ErrorStateComponent,
    RouterLink,
    TranslatePipe,
  ],
  templateUrl: './transaction-detail-page.html',
  styleUrl: './transaction-detail-page.scss',
})
export class TransactionDetailPageComponent implements OnInit {
  private readonly payments = inject(PaymentsService);
  private readonly route = inject(ActivatedRoute);

  protected readonly txn = signal<PaymentTransactionItem | null>(null);
  protected readonly loading = signal(true);
  protected readonly loadError = signal<string | null>(null);
  protected readonly refreshing = signal(false);
  protected readonly refreshError = signal<string | null>(null);

  private clientReference = '';

  async ngOnInit(): Promise<void> {
    this.clientReference = this.route.snapshot.paramMap.get('clientReference') ?? '';
    if (!this.clientReference) {
      this.loadError.set('Not found');
      this.loading.set(false);
      return;
    }
    await this.load();
  }

  protected amountLabel(row: PaymentTransactionItem): string {
    return `${row.amount} ${row.currencyCode}`.trim();
  }

  protected methodIcon(row: PaymentTransactionItem): string {
    const type = row.paymentMethod?.methodType?.value;
    switch (type) {
      case 'B':
        return 'account_balance';
      case 'M':
        return 'smartphone';
      case 'F':
        return 'payments';
      case 'C':
        return 'currency_bitcoin';
      default:
        return row.purpose?.value === 'W' ? 'account_balance_wallet' : 'payments';
    }
  }

  protected async onRefresh(): Promise<void> {
    if (this.refreshing() || !this.clientReference) {
      return;
    }
    this.refreshing.set(true);
    this.refreshError.set(null);
    try {
      const detail = await this.payments.refreshTransaction(this.clientReference);
      this.txn.set(detail);
    } catch (error) {
      this.refreshError.set((error as ApiError).message);
    } finally {
      this.refreshing.set(false);
    }
  }

  protected onRetry(): void {
    void this.load();
  }

  private async load(): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      const detail = await this.payments.getTransactionDetail(this.clientReference);
      this.txn.set(detail);
    } catch (error) {
      this.loadError.set((error as ApiError).message);
      this.txn.set(null);
    } finally {
      this.loading.set(false);
    }
  }
}
