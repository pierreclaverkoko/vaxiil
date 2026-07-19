import { Component, computed, input, model, output } from '@angular/core';

import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { ButtonComponent } from '@/shared/ui/button/button';
import { DataTableColumn, DataTableComponent } from '@/shared/ui/data-table/data-table';
import { EmptyStateComponent } from '@/shared/ui/empty-state/empty-state';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';
import { FiltersToolbarComponent } from '@/shared/ui/filters-toolbar/filters-toolbar';

@Component({
  selector: 'app-admin-resource-list',
  standalone: true,
  imports: [
    ButtonComponent,
    DataTableComponent,
    EmptyStateComponent,
    ErrorStateComponent,
    FiltersToolbarComponent,
    TranslatePipe,
  ],
  templateUrl: './admin-resource-list.html',
  styleUrl: './admin-resource-list.scss',
})
export class AdminResourceListComponent {
  readonly title = input('');
  readonly caption = input('');
  readonly columns = input<DataTableColumn[]>([]);
  readonly loading = input(false);
  readonly loadError = input<string | null>(null);
  readonly emptyTitle = input('');
  readonly emptyMessage = input('');
  readonly searchPlaceholder = input('ui.search');
  readonly showSearch = input(true);
  readonly showAdd = input(false);
  readonly addLabel = input('ui.add');
  readonly page = input(1);
  readonly pageSize = input(20);
  readonly totalCount = input(0);
  readonly hasNext = input(false);
  readonly hasPrevious = input(false);
  readonly rowCount = input(0);

  readonly search = model('');
  readonly ordering = model('');

  readonly searchChange = output<string>();
  readonly orderingChange = output<string>();
  readonly pageChange = output<number>();
  readonly addClick = output<void>();
  readonly retry = output<void>();

  protected readonly rangeLabel = computed(() => {
    const count = this.totalCount();
    if (!count || !this.rowCount()) {
      return '';
    }
    const start = (this.page() - 1) * this.pageSize() + 1;
    const end = start + this.rowCount() - 1;
    return `${start}–${end} / ${count}`;
  });

  protected onSearchInput(event: Event): void {
    const value = (event.target as HTMLInputElement).value;
    this.search.set(value);
    this.searchChange.emit(value);
  }

  protected onSort(value: string): void {
    this.ordering.set(value);
    this.orderingChange.emit(value);
  }

  protected prev(): void {
    if (this.hasPrevious()) {
      this.pageChange.emit(Math.max(1, this.page() - 1));
    }
  }

  protected next(): void {
    if (this.hasNext()) {
      this.pageChange.emit(this.page() + 1);
    }
  }
}
