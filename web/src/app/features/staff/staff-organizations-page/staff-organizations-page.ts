import { Component, OnInit, computed, inject, signal } from '@angular/core';

import { ApiError } from '@/core/http/api-error';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { staffOrgActions } from '@/features/staff/staff-actions';
import { StaffApiService, StaffOrgRow } from '@/features/staff/staff-api.service';
import { AdminResourceListComponent } from '@/shared/ui/admin-resource-list/admin-resource-list';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ChoiceEnumChipComponent } from '@/shared/ui/choice-enum-chip/choice-enum-chip';
import { DataTableColumn } from '@/shared/ui/data-table/data-table';
import { InputComponent } from '@/shared/ui/input/input';
import { ModalDialogComponent } from '@/shared/ui/modal-dialog/modal-dialog';
import { OptionCardGroupComponent, OptionCardItem } from '@/shared/ui/option-card-group/option-card-group';

@Component({
  selector: 'app-staff-organizations-page',
  standalone: true,
  imports: [
    AdminResourceListComponent,
    ButtonComponent,
    ChoiceEnumChipComponent,
    InputComponent,
    ModalDialogComponent,
    OptionCardGroupComponent,
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
  protected readonly search = signal('');
  protected readonly ordering = signal('-updated_at');
  protected readonly page = signal(1);
  protected readonly totalCount = signal(0);
  protected readonly hasNext = signal(false);
  protected readonly hasPrevious = signal(false);
  protected readonly rejectReason = signal('');
  protected readonly revenueAmount = signal('');
  protected readonly revenueCurrency = signal('USD');
  protected readonly revenueNote = signal('');
  protected readonly loading = signal(true);
  protected readonly busy = signal(false);
  protected readonly loadError = signal<string | null>(null);
  protected readonly actionError = signal<string | null>(null);
  protected readonly actionSuccess = signal<string | null>(null);
  protected readonly modalOpen = signal(false);

  private searchTimer: ReturnType<typeof setTimeout> | null = null;

  protected readonly columns = computed<DataTableColumn[]>(() => {
    this.locale.locale();
    return [
      { key: 'name', label: this.locale.t('staff.colName'), sortable: true },
      { key: 'email', label: this.locale.t('staff.colEmail'), sortable: true },
      { key: 'type', label: this.locale.t('staff.colType') },
      { key: 'status', label: this.locale.t('staff.colStatus') },
      { key: 'actions', label: this.locale.t('staff.colActions'), width: '14rem' },
    ];
  });

  protected readonly statusOptions = computed<OptionCardItem[]>(() => {
    this.locale.locale();
    return [
      { value: '', title: this.locale.t('staff.filterAll'), icon: 'filter_list' },
      { value: 'P', title: this.locale.t('staff.statusPending'), icon: 'hourglass_top' },
      { value: 'V', title: this.locale.t('staff.statusVerified'), icon: 'verified' },
      { value: 'R', title: this.locale.t('staff.statusRejected'), icon: 'cancel' },
      { value: 'S', title: this.locale.t('staff.statusSuspended'), icon: 'block' },
    ];
  });

  protected readonly selectedActions = computed(() =>
    staffOrgActions(this.selected()?.verificationStatus?.value),
  );

  async ngOnInit(): Promise<void> {
    await this.load();
  }

  protected actionsFor(row: StaffOrgRow) {
    return staffOrgActions(row.verificationStatus?.value);
  }

  protected onFilterStatus(value: string): void {
    this.filterStatus.set(value);
    this.page.set(1);
    void this.load();
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

  protected onPage(page: number): void {
    this.page.set(page);
    void this.load();
  }

  protected openRow(row: StaffOrgRow): void {
    this.selected.set(row);
    this.rejectReason.set('');
    this.revenueAmount.set('');
    this.revenueNote.set('');
    this.actionError.set(null);
    this.actionSuccess.set(null);
    this.modalOpen.set(true);
  }

  protected closeModal(): void {
    this.modalOpen.set(false);
  }

  protected async onApprove(): Promise<void> {
    const row = this.selected();
    if (!row || this.busy() || !this.selectedActions().canApprove) {
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
    if (!row || this.busy() || !this.selectedActions().canReject) {
      return;
    }
    this.busy.set(true);
    this.actionError.set(null);
    try {
      const updated = await this.api.rejectOrganization(row.id, this.rejectReason());
      this.selected.set(updated);
      this.actionSuccess.set(this.locale.t('staff.orgs.rejected'));
      await this.load();
    } catch (error) {
      this.actionError.set((error as ApiError).message);
    } finally {
      this.busy.set(false);
    }
  }

  protected async onSuspend(): Promise<void> {
    const row = this.selected();
    if (!row || this.busy() || !this.selectedActions().canSuspend) {
      return;
    }
    this.busy.set(true);
    this.actionError.set(null);
    try {
      const updated = await this.api.suspendOrganization(row.id);
      this.selected.set(updated);
      this.actionSuccess.set(this.locale.t('staff.suspended'));
      await this.load();
    } catch (error) {
      this.actionError.set((error as ApiError).message);
    } finally {
      this.busy.set(false);
    }
  }

  protected async onUnsuspend(): Promise<void> {
    const row = this.selected();
    if (!row || this.busy() || !this.selectedActions().canUnsuspend) {
      return;
    }
    this.busy.set(true);
    this.actionError.set(null);
    try {
      const updated = await this.api.unsuspendOrganization(row.id);
      this.selected.set(updated);
      this.actionSuccess.set(this.locale.t('staff.unsuspended'));
      await this.load();
    } catch (error) {
      this.actionError.set((error as ApiError).message);
    } finally {
      this.busy.set(false);
    }
  }

  protected async onRevenueDebit(): Promise<void> {
    const row = this.selected();
    if (!row || this.busy()) {
      return;
    }
    const amount = this.revenueAmount().trim();
    const currency = this.revenueCurrency().trim().toUpperCase();
    const note = this.revenueNote().trim();
    if (!amount || !currency || !note) {
      this.actionError.set(this.locale.t('staff.users.debitNoteRequired'));
      return;
    }
    this.busy.set(true);
    this.actionError.set(null);
    try {
      await this.api.debitOrgRevenue(row.id, {
        amount,
        currency_code: currency,
        note,
      });
      this.revenueAmount.set('');
      this.revenueNote.set('');
      this.actionSuccess.set(this.locale.t('staff.orgs.revenueDebited'));
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
        page: this.page(),
        verificationStatus: this.filterStatus() || undefined,
        search: this.search() || undefined,
        ordering: this.ordering() || undefined,
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
