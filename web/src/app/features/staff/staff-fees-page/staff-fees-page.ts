import { Component, OnInit, inject, signal } from '@angular/core';

import { ApiError } from '@/core/http/api-error';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import {
  StaffApiService,
  StaffCategoryFeeRow,
  StaffFeeEntryRow,
} from '@/features/staff/staff-api.service';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ChoiceEnumChipComponent } from '@/shared/ui/choice-enum-chip/choice-enum-chip';
import { DataTableComponent, DataTableColumn } from '@/shared/ui/data-table/data-table';
import { EmptyStateComponent } from '@/shared/ui/empty-state/empty-state';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';
import { InputComponent } from '@/shared/ui/input/input';

@Component({
  selector: 'app-staff-fees-page',
  standalone: true,
  imports: [
    ButtonComponent,
    ChoiceEnumChipComponent,
    DataTableComponent,
    EmptyStateComponent,
    ErrorStateComponent,
    InputComponent,
    TranslatePipe,
  ],
  templateUrl: './staff-fees-page.html',
  styleUrl: '../staff-queue.scss',
})
export class StaffFeesPageComponent implements OnInit {
  private readonly api = inject(StaffApiService);

  protected readonly tab = signal<'ledger' | 'config'>('ledger');
  protected readonly rows = signal<StaffFeeEntryRow[]>([]);
  protected readonly summary = signal<
    { currency: string; totalAccrued: string; totalReversed: string; netFees: string }[]
  >([]);
  protected readonly categoryFees = signal<StaffCategoryFeeRow[]>([]);
  protected readonly globalRate = signal('1.00');
  protected readonly orgId = signal('');
  protected readonly orgRate = signal('');
  protected readonly orgPayer = signal('C');
  protected readonly loading = signal(true);
  protected readonly loadError = signal<string | null>(null);
  protected readonly actionMessage = signal<string | null>(null);

  protected readonly columns: DataTableColumn[] = [
    { key: 'org', label: 'Organization' },
    { key: 'amount', label: 'Amount' },
    { key: 'rate', label: 'Rate' },
    { key: 'payer', label: 'Payer' },
    { key: 'status', label: 'Status' },
  ];

  async ngOnInit(): Promise<void> {
    await this.reload();
  }

  protected async reload(): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      const [page, summary, settings, cats] = await Promise.all([
        this.api.listFeeEntries(),
        this.api.feeSummary(),
        this.api.getPlatformSettings(),
        this.api.listCategoryFees(),
      ]);
      this.rows.set(page.results);
      this.summary.set(summary);
      this.globalRate.set(settings.platformFeeRate);
      this.categoryFees.set(cats.results);
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    } finally {
      this.loading.set(false);
    }
  }

  protected async onSaveGlobal(): Promise<void> {
    this.actionMessage.set(null);
    try {
      const updated = await this.api.patchPlatformSettings(this.globalRate().trim());
      this.globalRate.set(updated.platformFeeRate);
      this.actionMessage.set('Saved');
    } catch (error) {
      this.actionMessage.set((error as ApiError).message);
    }
  }

  protected async onSaveOrgFees(): Promise<void> {
    const id = this.orgId().trim();
    if (!id) {
      return;
    }
    this.actionMessage.set(null);
    try {
      await this.api.patchOrganizationFeeSettings(id, {
        platform_fee_rate: this.orgRate().trim() || null,
        platform_fee_payer: this.orgPayer(),
      });
      this.actionMessage.set('Saved company fee settings');
    } catch (error) {
      this.actionMessage.set((error as ApiError).message);
    }
  }

  protected async onClearOrgOverride(): Promise<void> {
    const id = this.orgId().trim();
    if (!id) {
      return;
    }
    try {
      await this.api.patchOrganizationFeeSettings(id, { clear_rate_override: true });
      this.orgRate.set('');
      this.actionMessage.set('Cleared company override');
    } catch (error) {
      this.actionMessage.set((error as ApiError).message);
    }
  }
}
