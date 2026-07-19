import { Component, OnInit, inject, signal } from '@angular/core';

import { ApiError } from '@/core/http/api-error';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { StaffApiService, StaffCategoryRow } from '@/features/staff/staff-api.service';
import { ButtonComponent } from '@/shared/ui/button/button';
import { DataTableComponent, DataTableColumn } from '@/shared/ui/data-table/data-table';
import { EmptyStateComponent } from '@/shared/ui/empty-state/empty-state';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';
import { InputComponent } from '@/shared/ui/input/input';

@Component({
  selector: 'app-staff-taxonomy-page',
  standalone: true,
  imports: [
    ButtonComponent,
    DataTableComponent,
    EmptyStateComponent,
    ErrorStateComponent,
    InputComponent,
    TranslatePipe,
  ],
  templateUrl: './staff-taxonomy-page.html',
  styleUrl: '../staff-queue.scss',
})
export class StaffTaxonomyPageComponent implements OnInit {
  private readonly api = inject(StaffApiService);
  private readonly locale = inject(LocaleService);

  protected readonly rows = signal<StaffCategoryRow[]>([]);
  protected readonly name = signal('');
  protected readonly icon = signal('');
  protected readonly description = signal('');
  protected readonly loading = signal(true);
  protected readonly busy = signal(false);
  protected readonly loadError = signal<string | null>(null);
  protected readonly actionError = signal<string | null>(null);
  protected readonly actionSuccess = signal<string | null>(null);

  protected readonly columns: DataTableColumn[] = [
    { key: 'name', label: 'Name' },
    { key: 'icon', label: 'Icon' },
    { key: 'active', label: 'Active' },
    { key: 'actions', label: 'Actions', width: '10rem' },
  ];

  async ngOnInit(): Promise<void> {
    await this.load();
  }

  protected async onCreate(event: Event): Promise<void> {
    event.preventDefault();
    const name = this.name().trim();
    if (!name || this.busy()) {
      return;
    }
    this.busy.set(true);
    this.actionError.set(null);
    try {
      await this.api.createCategory({
        name,
        icon: this.icon().trim(),
        description: this.description().trim(),
        is_active: true,
        sort_order: this.rows().length,
      });
      this.name.set('');
      this.icon.set('');
      this.description.set('');
      this.actionSuccess.set(this.locale.t('staff.taxonomy.created'));
      await this.load();
    } catch (error) {
      this.actionError.set((error as ApiError).message);
    } finally {
      this.busy.set(false);
    }
  }

  protected async toggleActive(row: StaffCategoryRow): Promise<void> {
    if (this.busy()) {
      return;
    }
    this.busy.set(true);
    this.actionError.set(null);
    try {
      await this.api.patchCategory(row.id, { is_active: !row.isActive });
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
      const page = await this.api.listCategories();
      this.rows.set(page.results);
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    } finally {
      this.loading.set(false);
    }
  }
}
