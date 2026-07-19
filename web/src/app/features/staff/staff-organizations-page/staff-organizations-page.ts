import { Component, OnInit, inject, signal } from '@angular/core';

import { ApiError } from '@/core/http/api-error';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { StaffApiService, StaffOrgRow } from '@/features/staff/staff-api.service';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ChoiceEnumChipComponent } from '@/shared/ui/choice-enum-chip/choice-enum-chip';
import { DataTableComponent, DataTableColumn } from '@/shared/ui/data-table/data-table';
import { EmptyStateComponent } from '@/shared/ui/empty-state/empty-state';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';
import { InputComponent } from '@/shared/ui/input/input';

@Component({
  selector: 'app-staff-organizations-page',
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
  templateUrl: './staff-organizations-page.html',
  styleUrl: '../staff-queue.scss',
})
export class StaffOrganizationsPageComponent implements OnInit {
  private readonly api = inject(StaffApiService);
  private readonly locale = inject(LocaleService);

  protected readonly rows = signal<StaffOrgRow[]>([]);
  protected readonly selected = signal<StaffOrgRow | null>(null);
  protected readonly filterStatus = signal('P');
  protected readonly rejectReason = signal('');
  protected readonly loading = signal(true);
  protected readonly busy = signal(false);
  protected readonly loadError = signal<string | null>(null);
  protected readonly actionError = signal<string | null>(null);
  protected readonly actionSuccess = signal<string | null>(null);

  protected readonly columns: DataTableColumn[] = [
    { key: 'name', label: 'Name' },
    { key: 'email', label: 'Email' },
    { key: 'type', label: 'Type' },
    { key: 'status', label: 'Status' },
    { key: 'actions', label: 'Actions', width: '12rem' },
  ];

  async ngOnInit(): Promise<void> {
    await this.load();
  }

  protected onFilterChange(event: Event): void {
    this.filterStatus.set((event.target as HTMLSelectElement).value);
    void this.load();
  }

  protected selectRow(row: StaffOrgRow): void {
    this.selected.set(row);
    this.rejectReason.set('');
    this.actionError.set(null);
    this.actionSuccess.set(null);
  }

  protected async onApprove(): Promise<void> {
    const row = this.selected();
    if (!row || this.busy()) {
      return;
    }
    this.busy.set(true);
    this.actionError.set(null);
    try {
      const updated = await this.api.approveOrganization(row.id);
      this.selected.set(updated);
      this.actionSuccess.set(this.locale.t('staff.orgs.approved'));
      await this.load();
    } catch (error) {
      this.actionError.set((error as ApiError).message);
    } finally {
      this.busy.set(false);
    }
  }

  protected async onReject(): Promise<void> {
    const row = this.selected();
    const reason = this.rejectReason().trim();
    if (!row || this.busy() || !reason) {
      return;
    }
    this.busy.set(true);
    this.actionError.set(null);
    try {
      const updated = await this.api.rejectOrganization(row.id, reason);
      this.selected.set(updated);
      this.actionSuccess.set(this.locale.t('staff.orgs.rejected'));
      await this.load();
    } catch (error) {
      this.actionError.set((error as ApiError).message);
    } finally {
      this.busy.set(false);
    }
  }

  private async load(): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      const page = await this.api.listOrganizations({
        verificationStatus: this.filterStatus() || undefined,
      });
      this.rows.set(page.results);
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    } finally {
      this.loading.set(false);
    }
  }
}
