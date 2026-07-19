import { Component, OnInit, inject, signal } from '@angular/core';

import { ApiError } from '@/core/http/api-error';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { StaffApiService, StaffPaymentRow } from '@/features/staff/staff-api.service';
import { ChoiceEnumChipComponent } from '@/shared/ui/choice-enum-chip/choice-enum-chip';
import { DataTableComponent, DataTableColumn } from '@/shared/ui/data-table/data-table';
import { EmptyStateComponent } from '@/shared/ui/empty-state/empty-state';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';

@Component({
  selector: 'app-staff-payments-page',
  standalone: true,
  imports: [
    ChoiceEnumChipComponent,
    DataTableComponent,
    EmptyStateComponent,
    ErrorStateComponent,
    TranslatePipe,
  ],
  templateUrl: './staff-payments-page.html',
  styleUrl: '../staff-queue.scss',
})
export class StaffPaymentsPageComponent implements OnInit {
  private readonly api = inject(StaffApiService);

  protected readonly rows = signal<StaffPaymentRow[]>([]);
  protected readonly loading = signal(true);
  protected readonly loadError = signal<string | null>(null);

  protected readonly columns: DataTableColumn[] = [
    { key: 'ref', label: 'Reference' },
    { key: 'user', label: 'User' },
    { key: 'provider', label: 'Provider' },
    { key: 'amount', label: 'Amount' },
    { key: 'status', label: 'Status' },
  ];

  async ngOnInit(): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      const page = await this.api.listPayments();
      this.rows.set(page.results);
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    } finally {
      this.loading.set(false);
    }
  }
}
