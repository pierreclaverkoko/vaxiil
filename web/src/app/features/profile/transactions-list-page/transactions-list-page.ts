import { DatePipe } from '@angular/common';
import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { ApiError } from '@/core/http/api-error';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { PaymentsService } from '@/features/bookings/payments.service';
import { PaymentTransactionItem } from '@/models/payment-transaction';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ChoiceEnumChipComponent } from '@/shared/ui/choice-enum-chip/choice-enum-chip';
import { EmptyStateComponent } from '@/shared/ui/empty-state/empty-state';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';
import {
  OptionCardGroupComponent,
  OptionCardItem,
} from '@/shared/ui/option-card-group/option-card-group';

@Component({
  selector: 'app-transactions-list-page',
  standalone: true,
  imports: [
    ButtonComponent,
    ChoiceEnumChipComponent,
    DatePipe,
    EmptyStateComponent,
    ErrorStateComponent,
    OptionCardGroupComponent,
    TranslatePipe,
  ],
  templateUrl: './transactions-list-page.html',
  styleUrl: './transactions-list-page.scss',
})
export class TransactionsListPageComponent implements OnInit {
  private readonly payments = inject(PaymentsService);
  private readonly locale = inject(LocaleService);
  private readonly router = inject(Router);

  protected readonly rows = signal<PaymentTransactionItem[]>([]);
  protected readonly filterStatus = signal('');
  protected readonly loading = signal(true);
  protected readonly loadError = signal<string | null>(null);
  protected readonly hasMore = signal(false);
  private page = 1;

  protected readonly statusOptions = computed<OptionCardItem[]>(() => {
    this.locale.locale();
    return [
      { value: '', title: this.locale.t('transactions.filterAll'), icon: 'filter_list' },
      {
        value: 'S',
        title: this.locale.t('transactions.statusSucceeded'),
        icon: 'check_circle',
      },
      {
        value: 'N',
        title: this.locale.t('transactions.statusPending'),
        icon: 'hourglass_top',
      },
      {
        value: 'G',
        title: this.locale.t('transactions.statusProcessing'),
        icon: 'sync',
      },
      { value: 'F', title: this.locale.t('transactions.statusFailed'), icon: 'error' },
    ];
  });

  async ngOnInit(): Promise<void> {
    await this.load(true);
  }

  protected onFilterStatus(value: string): void {
    this.filterStatus.set(value);
    void this.load(true);
  }

  protected onRetry(): void {
    void this.load(true);
  }

  protected onLoadMore(): void {
    void this.load(false);
  }

  protected onOpenDetail(row: PaymentTransactionItem): void {
    if (!row.clientReference) {
      return;
    }
    void this.router.navigate(['/profile/transactions', row.clientReference]);
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

  private async load(reset: boolean): Promise<void> {
    if (reset) {
      this.page = 1;
      this.loading.set(true);
      this.loadError.set(null);
    }
    try {
      const response = await this.payments.listTransactions({
        page: this.page,
        status: this.filterStatus() || undefined,
      });
      if (reset) {
        this.rows.set(response.results);
      } else {
        this.rows.update((prev) => [...prev, ...response.results]);
      }
      this.hasMore.set(response.next != null);
      this.page += 1;
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    } finally {
      this.loading.set(false);
    }
  }
}
