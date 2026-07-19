import { Component, OnInit, computed, inject, signal } from '@angular/core';

import { ApiError } from '@/core/http/api-error';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import {
  StaffApiService,
  StaffCategoryFeeRow,
  StaffFeeEntryRow,
} from '@/features/staff/staff-api.service';
import { AdminResourceListComponent } from '@/shared/ui/admin-resource-list/admin-resource-list';
import {
  AutocompleteFieldComponent,
  AutocompleteOption,
} from '@/shared/ui/autocomplete-field/autocomplete-field';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ChoiceEnumChipComponent } from '@/shared/ui/choice-enum-chip/choice-enum-chip';
import { DataTableColumn } from '@/shared/ui/data-table/data-table';
import { InputComponent } from '@/shared/ui/input/input';
import { ModalDialogComponent } from '@/shared/ui/modal-dialog/modal-dialog';
import { OptionCardGroupComponent, OptionCardItem } from '@/shared/ui/option-card-group/option-card-group';
import { SegmentedTab, SegmentedTabsComponent } from '@/shared/ui/segmented-tabs/segmented-tabs';

type FeesTab = 'ledger' | 'config' | 'categories';

@Component({
  selector: 'app-staff-fees-page',
  standalone: true,
  imports: [
    AdminResourceListComponent,
    AutocompleteFieldComponent,
    ButtonComponent,
    ChoiceEnumChipComponent,
    InputComponent,
    ModalDialogComponent,
    OptionCardGroupComponent,
    SegmentedTabsComponent,
    TranslatePipe,
  ],
  templateUrl: './staff-fees-page.html',
  styleUrl: '../staff-queue.scss',
})
export class StaffFeesPageComponent implements OnInit {
  private readonly api = inject(StaffApiService);
  private readonly locale = inject(LocaleService);

  protected readonly tab = signal<FeesTab>('ledger');
  protected readonly rows = signal<StaffFeeEntryRow[]>([]);
  protected readonly summary = signal<
    { currency: string; totalAccrued: string; totalReversed: string; netFees: string }[]
  >([]);
  protected readonly categoryFees = signal<StaffCategoryFeeRow[]>([]);
  protected readonly globalRate = signal('1.00');
  protected readonly orgId = signal<string | null>(null);
  protected readonly orgQuery = signal('');
  protected readonly orgOptions = signal<AutocompleteOption[]>([]);
  protected readonly orgLoading = signal(false);
  protected readonly orgRate = signal('');
  protected readonly orgPayer = signal('C');
  protected readonly page = signal(1);
  protected readonly totalCount = signal(0);
  protected readonly hasNext = signal(false);
  protected readonly hasPrevious = signal(false);
  protected readonly search = signal('');
  protected readonly loading = signal(true);
  protected readonly loadError = signal<string | null>(null);
  protected readonly actionMessage = signal<string | null>(null);
  protected readonly modalOpen = signal(false);
  protected readonly newCategoryId = signal<string | null>(null);
  protected readonly newCategoryQuery = signal('');
  protected readonly newCategoryOptions = signal<AutocompleteOption[]>([]);
  protected readonly newCategoryLoading = signal(false);
  protected readonly newCategoryRate = signal('');
  protected readonly busy = signal(false);

  private searchTimer: ReturnType<typeof setTimeout> | null = null;

  protected readonly tabs = computed<SegmentedTab[]>(() => {
    this.locale.locale();
    return [
      { id: 'ledger', label: this.locale.t('staff.fees.ledger'), icon: 'receipt_long' },
      { id: 'config', label: this.locale.t('staff.fees.config'), icon: 'settings' },
      { id: 'categories', label: this.locale.t('staff.fees.categoryFees'), icon: 'category' },
    ];
  });

  protected readonly payerOptions = computed<OptionCardItem[]>(() => {
    this.locale.locale();
    return [
      {
        value: 'C',
        title: this.locale.t('staff.fees.payerClient'),
        description: this.locale.t('staff.fees.payerClientDesc'),
        icon: 'person',
      },
      {
        value: 'B',
        title: this.locale.t('staff.fees.payerBusiness'),
        description: this.locale.t('staff.fees.payerBusinessDesc'),
        icon: 'storefront',
      },
    ];
  });

  protected readonly columns = computed<DataTableColumn[]>(() => {
    this.locale.locale();
    return [
      { key: 'org', label: this.locale.t('staff.colOrg') },
      { key: 'amount', label: this.locale.t('staff.colAmount'), sortable: true },
      { key: 'rate', label: this.locale.t('staff.colRate') },
      { key: 'payer', label: this.locale.t('staff.colPayer') },
      { key: 'status', label: this.locale.t('staff.colStatus'), sortable: true },
    ];
  });

  protected readonly categoryColumns = computed<DataTableColumn[]>(() => {
    this.locale.locale();
    return [
      { key: 'category', label: this.locale.t('staff.colCategory') },
      { key: 'rate', label: this.locale.t('staff.colRate') },
    ];
  });

  async ngOnInit(): Promise<void> {
    await this.reload();
  }

  protected onTab(id: string): void {
    this.tab.set(id as FeesTab);
  }

  protected onSearch(value: string): void {
    this.search.set(value);
    if (this.searchTimer) {
      clearTimeout(this.searchTimer);
    }
    this.searchTimer = setTimeout(() => {
      this.page.set(1);
      void this.loadLedger();
    }, 300);
  }

  protected onPage(page: number): void {
    this.page.set(page);
    void this.loadLedger();
  }

  protected async onOrgQuery(q: string): Promise<void> {
    this.orgQuery.set(q);
    this.orgLoading.set(true);
    try {
      const page = await this.api.listOrganizations({ page: 1, search: q, pageSize: 20 });
      this.orgOptions.set(
        page.results.map((o) => ({
          id: o.id,
          label: o.name,
          description: o.email,
        })),
      );
    } finally {
      this.orgLoading.set(false);
    }
  }

  protected onOrgPick(opt: AutocompleteOption | null): void {
    this.orgId.set(opt?.id ?? null);
  }

  protected async onCategoryQuery(q: string): Promise<void> {
    this.newCategoryQuery.set(q);
    this.newCategoryLoading.set(true);
    try {
      const page = await this.api.listCategories({ page: 1, search: q, pageSize: 20 });
      this.newCategoryOptions.set(
        page.results.map((c) => ({ id: c.id, label: c.name })),
      );
    } finally {
      this.newCategoryLoading.set(false);
    }
  }

  protected onCategoryPick(opt: AutocompleteOption | null): void {
    this.newCategoryId.set(opt?.id ?? null);
  }

  protected openAddCategoryFee(): void {
    this.newCategoryId.set(null);
    this.newCategoryQuery.set('');
    this.newCategoryRate.set('');
    this.actionMessage.set(null);
    this.modalOpen.set(true);
    void this.onCategoryQuery('');
  }

  protected async onSaveGlobal(): Promise<void> {
    this.actionMessage.set(null);
    try {
      const updated = await this.api.patchPlatformSettings(this.globalRate().trim());
      this.globalRate.set(updated.platformFeeRate);
      this.actionMessage.set(this.locale.t('staff.fees.saved'));
    } catch (error) {
      this.actionMessage.set((error as ApiError).message);
    }
  }

  protected async onSaveOrgFees(): Promise<void> {
    const id = this.orgId();
    if (!id) {
      return;
    }
    this.actionMessage.set(null);
    try {
      await this.api.patchOrganizationFeeSettings(id, {
        platform_fee_rate: this.orgRate().trim() || null,
        platform_fee_payer: this.orgPayer(),
      });
      this.actionMessage.set(this.locale.t('staff.fees.saved'));
    } catch (error) {
      this.actionMessage.set((error as ApiError).message);
    }
  }

  protected async onClearOrgOverride(): Promise<void> {
    const id = this.orgId();
    if (!id) {
      return;
    }
    try {
      await this.api.patchOrganizationFeeSettings(id, { clear_rate_override: true });
      this.orgRate.set('');
      this.actionMessage.set(this.locale.t('staff.fees.saved'));
    } catch (error) {
      this.actionMessage.set((error as ApiError).message);
    }
  }

  protected async onCreateCategoryFee(): Promise<void> {
    const categoryId = this.newCategoryId();
    const rate = this.newCategoryRate().trim();
    if (!categoryId || !rate || this.busy()) {
      return;
    }
    this.busy.set(true);
    try {
      await this.api.createCategoryFee(categoryId, rate);
      this.actionMessage.set(this.locale.t('staff.fees.categoryFeeCreated'));
      this.modalOpen.set(false);
      const cats = await this.api.listCategoryFees();
      this.categoryFees.set(cats.results);
    } catch (error) {
      this.actionMessage.set((error as ApiError).message);
    } finally {
      this.busy.set(false);
    }
  }

  protected async reload(): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      const [summary, settings, cats] = await Promise.all([
        this.api.feeSummary(),
        this.api.getPlatformSettings(),
        this.api.listCategoryFees(),
      ]);
      this.summary.set(summary);
      this.globalRate.set(settings.platformFeeRate);
      this.categoryFees.set(cats.results);
      await this.loadLedger();
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    } finally {
      this.loading.set(false);
    }
  }

  private async loadLedger(): Promise<void> {
    const page = await this.api.listFeeEntries({
      page: this.page(),
      search: this.search() || undefined,
      organization: this.orgId() || undefined,
    });
    this.rows.set(page.results);
    this.totalCount.set(page.count);
    this.hasNext.set(page.next != null);
    this.hasPrevious.set(page.previous != null);
  }
}
