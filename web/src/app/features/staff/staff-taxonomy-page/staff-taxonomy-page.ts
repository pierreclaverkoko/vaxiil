import { Component, OnInit, computed, inject, signal } from '@angular/core';

import { ApiError } from '@/core/http/api-error';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import {
  StaffApiService,
  StaffCategoryRow,
  StaffFeatureRow,
  StaffSubCategoryRow,
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

type TaxonomyTab = 'categories' | 'subcategories' | 'features';

@Component({
  selector: 'app-staff-taxonomy-page',
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
  templateUrl: './staff-taxonomy-page.html',
  styleUrl: '../staff-queue.scss',
})
export class StaffTaxonomyPageComponent implements OnInit {
  private readonly api = inject(StaffApiService);
  private readonly locale = inject(LocaleService);

  protected readonly tab = signal<TaxonomyTab>('categories');
  protected readonly categories = signal<StaffCategoryRow[]>([]);
  protected readonly subcategories = signal<StaffSubCategoryRow[]>([]);
  protected readonly features = signal<StaffFeatureRow[]>([]);
  protected readonly search = signal('');
  protected readonly page = signal(1);
  protected readonly totalCount = signal(0);
  protected readonly hasNext = signal(false);
  protected readonly hasPrevious = signal(false);
  protected readonly loading = signal(true);
  protected readonly busy = signal(false);
  protected readonly loadError = signal<string | null>(null);
  protected readonly actionError = signal<string | null>(null);
  protected readonly actionSuccess = signal<string | null>(null);
  protected readonly modalOpen = signal(false);
  protected readonly editingId = signal<string | null>(null);

  protected readonly formName = signal('');
  protected readonly formIcon = signal('');
  protected readonly formDescription = signal('');
  protected readonly formCategoryId = signal<string | null>(null);
  protected readonly formFeatureType = signal('A');
  protected readonly categoryOptions = signal<AutocompleteOption[]>([]);
  protected readonly categoryQuery = signal('');
  protected readonly categoryLoading = signal(false);

  private searchTimer: ReturnType<typeof setTimeout> | null = null;

  protected readonly tabs = computed<SegmentedTab[]>(() => {
    this.locale.locale();
    return [
      { id: 'categories', label: this.locale.t('staff.taxonomy.tabCategories'), icon: 'category' },
      {
        id: 'subcategories',
        label: this.locale.t('staff.taxonomy.tabSubcategories'),
        icon: 'account_tree',
      },
      { id: 'features', label: this.locale.t('staff.taxonomy.tabFeatures'), icon: 'tune' },
    ];
  });

  protected readonly featureTypeOptions = computed<OptionCardItem[]>(() => {
    this.locale.locale();
    return [
      {
        value: 'A',
        title: this.locale.t('staff.taxonomy.featureTypeAmenity'),
        description: this.locale.t('staff.taxonomy.featureTypeAmenityDesc'),
        icon: 'spa',
      },
      {
        value: 'R',
        title: this.locale.t('staff.taxonomy.featureTypeRequirement'),
        description: this.locale.t('staff.taxonomy.featureTypeRequirementDesc'),
        icon: 'checklist',
      },
      {
        value: 'S',
        title: this.locale.t('staff.taxonomy.featureTypeSpecialty'),
        description: this.locale.t('staff.taxonomy.featureTypeSpecialtyDesc'),
        icon: 'star',
      },
    ];
  });

  protected readonly columns = computed<DataTableColumn[]>(() => {
    this.locale.locale();
    const tab = this.tab();
    if (tab === 'categories') {
      return [
        { key: 'name', label: this.locale.t('staff.colName'), sortable: true },
        { key: 'icon', label: this.locale.t('staff.colIcon') },
        { key: 'active', label: this.locale.t('staff.colActive') },
        { key: 'actions', label: this.locale.t('staff.colActions'), width: '12rem' },
      ];
    }
    if (tab === 'subcategories') {
      return [
        { key: 'name', label: this.locale.t('staff.colName'), sortable: true },
        { key: 'category', label: this.locale.t('staff.colCategory') },
        { key: 'active', label: this.locale.t('staff.colActive') },
        { key: 'actions', label: this.locale.t('staff.colActions'), width: '12rem' },
      ];
    }
    return [
      { key: 'name', label: this.locale.t('staff.colName'), sortable: true },
      { key: 'type', label: this.locale.t('staff.taxonomy.featureType') },
      { key: 'icon', label: this.locale.t('staff.colIcon') },
      { key: 'actions', label: this.locale.t('staff.colActions'), width: '8rem' },
    ];
  });

  protected readonly rowCount = computed(() => {
    const tab = this.tab();
    if (tab === 'categories') {
      return this.categories().length;
    }
    if (tab === 'subcategories') {
      return this.subcategories().length;
    }
    return this.features().length;
  });

  async ngOnInit(): Promise<void> {
    await this.load();
  }

  protected onTab(id: string): void {
    this.tab.set(id as TaxonomyTab);
    this.page.set(1);
    this.search.set('');
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

  protected onPage(page: number): void {
    this.page.set(page);
    void this.load();
  }

  protected openCreate(): void {
    this.editingId.set(null);
    this.formName.set('');
    this.formIcon.set('');
    this.formDescription.set('');
    this.formCategoryId.set(null);
    this.formFeatureType.set('A');
    this.categoryQuery.set('');
    this.actionError.set(null);
    this.actionSuccess.set(null);
    this.modalOpen.set(true);
    if (this.tab() === 'subcategories') {
      void this.loadCategoryOptions('');
    }
  }

  protected openEditCategory(row: StaffCategoryRow): void {
    this.editingId.set(row.id);
    this.formName.set(row.name);
    this.formIcon.set(row.icon);
    this.formDescription.set(row.description);
    this.modalOpen.set(true);
  }

  protected openEditSub(row: StaffSubCategoryRow): void {
    this.editingId.set(row.id);
    this.formName.set(row.name);
    this.formDescription.set(row.description);
    this.formCategoryId.set(row.categoryId);
    this.categoryQuery.set(row.categoryName);
    this.modalOpen.set(true);
    void this.loadCategoryOptions(row.categoryName);
  }

  protected openEditFeature(row: StaffFeatureRow): void {
    this.editingId.set(row.id);
    this.formName.set(row.name);
    this.formIcon.set(row.icon);
    this.formDescription.set(row.description);
    this.formFeatureType.set(
      row.featureType?.value != null ? String(row.featureType.value) : 'A',
    );
    this.modalOpen.set(true);
  }

  protected async onCategoryQuery(q: string): Promise<void> {
    this.categoryQuery.set(q);
    await this.loadCategoryOptions(q);
  }

  protected onCategoryPick(opt: AutocompleteOption | null): void {
    this.formCategoryId.set(opt?.id ?? null);
  }

  protected async save(): Promise<void> {
    const name = this.formName().trim();
    if (!name || this.busy()) {
      return;
    }
    this.busy.set(true);
    this.actionError.set(null);
    try {
      const tab = this.tab();
      const id = this.editingId();
      if (tab === 'categories') {
        if (id) {
          await this.api.patchCategory(id, {
            name,
            icon: this.formIcon().trim(),
            description: this.formDescription().trim(),
          });
        } else {
          await this.api.createCategory({
            name,
            icon: this.formIcon().trim(),
            description: this.formDescription().trim(),
            is_active: true,
          });
        }
      } else if (tab === 'subcategories') {
        const category = this.formCategoryId();
        if (!category) {
          this.actionError.set(this.locale.t('staff.taxonomy.category'));
          return;
        }
        if (id) {
          await this.api.patchSubcategory(id, {
            name,
            category,
            description: this.formDescription().trim(),
          });
        } else {
          await this.api.createSubcategory({
            name,
            category,
            description: this.formDescription().trim(),
            is_active: true,
          });
        }
      } else if (id) {
        await this.api.patchFeature(id, {
          name,
          feature_type: this.formFeatureType(),
          description: this.formDescription().trim(),
          icon: this.formIcon().trim(),
        });
      } else {
        await this.api.createFeature({
          name,
          feature_type: this.formFeatureType(),
          description: this.formDescription().trim(),
          icon: this.formIcon().trim(),
        });
      }
      this.actionSuccess.set(
        this.locale.t(id ? 'staff.taxonomy.updated' : 'staff.taxonomy.created'),
      );
      this.modalOpen.set(false);
      await this.load();
    } catch (error) {
      this.actionError.set((error as ApiError).message);
    } finally {
      this.busy.set(false);
    }
  }

  protected async toggleCategory(row: StaffCategoryRow): Promise<void> {
    await this.api.patchCategory(row.id, { is_active: !row.isActive });
    await this.load();
  }

  protected async toggleSub(row: StaffSubCategoryRow): Promise<void> {
    await this.api.patchSubcategory(row.id, { is_active: !row.isActive });
    await this.load();
  }

  private async loadCategoryOptions(search: string): Promise<void> {
    this.categoryLoading.set(true);
    try {
      const page = await this.api.listCategories({ page: 1, search, pageSize: 20 });
      this.categoryOptions.set(
        page.results.map((c) => ({ id: c.id, label: c.name, description: c.icon })),
      );
    } finally {
      this.categoryLoading.set(false);
    }
  }

  private async load(): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      const params = {
        page: this.page(),
        search: this.search() || undefined,
      };
      const tab = this.tab();
      if (tab === 'categories') {
        const page = await this.api.listCategories(params);
        this.categories.set(page.results);
        this.totalCount.set(page.count);
        this.hasNext.set(page.next != null);
        this.hasPrevious.set(page.previous != null);
      } else if (tab === 'subcategories') {
        const page = await this.api.listSubcategories(params);
        this.subcategories.set(page.results);
        this.totalCount.set(page.count);
        this.hasNext.set(page.next != null);
        this.hasPrevious.set(page.previous != null);
      } else {
        const page = await this.api.listFeatures(params);
        this.features.set(page.results);
        this.totalCount.set(page.count);
        this.hasNext.set(page.next != null);
        this.hasPrevious.set(page.previous != null);
      }
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    } finally {
      this.loading.set(false);
    }
  }
}
