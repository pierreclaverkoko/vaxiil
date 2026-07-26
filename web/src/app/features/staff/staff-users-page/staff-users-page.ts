import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { ApiError } from '@/core/http/api-error';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { staffUserActions } from '@/features/staff/staff-actions';
import { StaffApiService, StaffUserRow } from '@/features/staff/staff-api.service';
import { AdminResourceListComponent } from '@/shared/ui/admin-resource-list/admin-resource-list';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ChoiceEnumChipComponent } from '@/shared/ui/choice-enum-chip/choice-enum-chip';
import { DataTableColumn } from '@/shared/ui/data-table/data-table';
import { OptionCardGroupComponent, OptionCardItem } from '@/shared/ui/option-card-group/option-card-group';

@Component({
  selector: 'app-staff-users-page',
  standalone: true,
  imports: [
    AdminResourceListComponent,
    ButtonComponent,
    ChoiceEnumChipComponent,
    OptionCardGroupComponent,
    TranslatePipe,
  ],
  templateUrl: './staff-users-page.html',
  styleUrl: '../staff-queue.scss',
})
export class StaffUsersPageComponent implements OnInit {
  private readonly api = inject(StaffApiService);
  private readonly locale = inject(LocaleService);
  private readonly router = inject(Router);

  protected readonly rows = signal<StaffUserRow[]>([]);
  protected readonly filterStatus = signal('P');
  protected readonly search = signal('');
  protected readonly ordering = signal('-updated_at');
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
      { key: 'email', label: this.locale.t('staff.colEmail'), sortable: true },
      { key: 'name', label: this.locale.t('staff.colName') },
      { key: 'status', label: this.locale.t('staff.colStatus') },
      { key: 'actions', label: this.locale.t('staff.colActions'), width: '12rem' },
    ];
  });

  protected readonly statusOptions = computed<OptionCardItem[]>(() => {
    this.locale.locale();
    return [
      { value: '', title: this.locale.t('staff.filterAll'), icon: 'filter_list' },
      {
        value: 'P',
        title: this.locale.t('staff.statusPending'),
        icon: 'hourglass_top',
        description: this.locale.t('staff.users.lede'),
      },
      { value: 'V', title: this.locale.t('staff.statusVerified'), icon: 'verified' },
      { value: 'R', title: this.locale.t('staff.statusRejected'), icon: 'cancel' },
    ];
  });

  async ngOnInit(): Promise<void> {
    await this.load();
  }

  protected actionsFor(row: StaffUserRow) {
    return staffUserActions(row.verificationStatus?.value);
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

  protected openRow(row: StaffUserRow): void {
    void this.router.navigate(['/staff/users', row.id]);
  }

  private async load(): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      const page = await this.api.listUsers({
        page: this.page(),
        search: this.search(),
        ordering: this.ordering(),
        verificationStatus: this.filterStatus() || undefined,
      });
      this.rows.set(page.results);
      this.totalCount.set(page.count);
      this.hasNext.set(!!page.next);
      this.hasPrevious.set(!!page.previous);
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    } finally {
      this.loading.set(false);
    }
  }
}
