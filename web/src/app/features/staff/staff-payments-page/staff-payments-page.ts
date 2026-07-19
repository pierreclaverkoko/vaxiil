import { Component, OnInit, computed, inject, signal } from '@angular/core';

import { ApiError } from '@/core/http/api-error';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { StaffApiService, StaffPaymentRow } from '@/features/staff/staff-api.service';
import { AdminResourceListComponent } from '@/shared/ui/admin-resource-list/admin-resource-list';
import { ChoiceEnumChipComponent } from '@/shared/ui/choice-enum-chip/choice-enum-chip';
import { DataTableColumn } from '@/shared/ui/data-table/data-table';
import { OptionCardGroupComponent, OptionCardItem } from '@/shared/ui/option-card-group/option-card-group';

@Component({
  selector: 'app-staff-payments-page',
  standalone: true,
  imports: [
    AdminResourceListComponent,
    ChoiceEnumChipComponent,
    OptionCardGroupComponent,
    TranslatePipe,
  ],
  templateUrl: './staff-payments-page.html',
  styleUrl: '../staff-queue.scss',
})
export class StaffPaymentsPageComponent implements OnInit {
  private readonly api = inject(StaffApiService);
  private readonly locale = inject(LocaleService);

  protected readonly rows = signal<StaffPaymentRow[]>([]);
  protected readonly search = signal('');
  protected readonly ordering = signal('-created_at');
  protected readonly filterStatus = signal('');
  protected readonly page = signal(1);
  protected readonly totalCount = signal(0);
  protected readonly hasNext = signal(false);
  protected readonly hasPrevious = signal(false);
  protected readonly loading = signal(true);
  protected readonly loadError = signal<string | null>(null);

  private searchTimer: ReturnType<typeof setTimeout> | null = null;

  protected readonly columns = computed<DataTableColumn[]>(() => {
    this.locale.locale();
    return [
      { key: 'created_at', label: this.locale.t('staff.colWhen'), sortable: true, sortKey: 'created_at' },
      { key: 'amount', label: this.locale.t('staff.colAmount'), sortable: true },
      { key: 'provider', label: this.locale.t('staff.colProvider') },
      { key: 'kind', label: this.locale.t('staff.colKind') },
      { key: 'status', label: this.locale.t('staff.colStatus'), sortable: true },
      { key: 'email', label: this.locale.t('staff.colEmail') },
    ];
  });

  protected readonly statusOptions = computed<OptionCardItem[]>(() => {
    this.locale.locale();
    return [
      { value: '', title: this.locale.t('staff.filterAll'), icon: 'filter_list' },
      {
        value: 'N',
        title: this.locale.t('staff.payments.statusPending'),
        icon: 'hourglass_top',
      },
      {
        value: 'G',
        title: this.locale.t('staff.payments.statusProcessing'),
        icon: 'sync',
      },
      {
        value: 'S',
        title: this.locale.t('staff.payments.statusSucceeded'),
        icon: 'check_circle',
      },
      { value: 'F', title: this.locale.t('staff.payments.statusFailed'), icon: 'error' },
      {
        value: 'X',
        title: this.locale.t('staff.payments.statusCancelled'),
        icon: 'cancel',
      },
    ];
  });

  async ngOnInit(): Promise<void> {
    await this.load();
  }

  protected onSearch(value: string): void {
    this.search.set(value);
    if (this.searchTimer) {
      clearTimeout(this.searchTimer);
    }
    this.searchTimer = setTimeout(() => {
      this.page.set(1);
      void this.load();
    }, 300);
  }

  protected onOrdering(value: string): void {
    this.ordering.set(value);
    this.page.set(1);
    void this.load();
  }

  protected onFilterStatus(value: string): void {
    this.filterStatus.set(value);
    this.page.set(1);
    void this.load();
  }

  protected onPage(page: number): void {
    this.page.set(page);
    void this.load();
  }

  private async load(): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      const page = await this.api.listPayments({
        page: this.page(),
        search: this.search() || undefined,
        ordering: this.ordering() || undefined,
        status: this.filterStatus() || undefined,
      });
      this.rows.set(page.results);
      this.totalCount.set(page.count);
      this.hasNext.set(page.next != null);
      this.hasPrevious.set(page.previous != null);
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    } finally {
      this.loading.set(false);
    }
  }
}
