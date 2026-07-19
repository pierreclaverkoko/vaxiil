import { Component, input, output } from '@angular/core';

export interface DataTableColumn {
  key: string;
  label: string;
  width?: string;
  sortable?: boolean;
  /** Backend ordering field when different from key. */
  sortKey?: string;
}

@Component({
  selector: 'app-data-table',
  standalone: true,
  templateUrl: './data-table.html',
  styleUrl: './data-table.scss',
})
export class DataTableComponent {
  readonly columns = input<DataTableColumn[]>([]);
  readonly caption = input('');
  /** Current ordering value, e.g. `-updated_at` or `name`. */
  readonly ordering = input('');
  readonly sortChange = output<string>();

  protected onSort(col: DataTableColumn): void {
    if (!col.sortable) {
      return;
    }
    const field = col.sortKey ?? col.key;
    const current = this.ordering();
    if (current === field) {
      this.sortChange.emit(`-${field}`);
    } else if (current === `-${field}`) {
      this.sortChange.emit(field);
    } else {
      this.sortChange.emit(field);
    }
  }

  protected sortIndicator(col: DataTableColumn): string {
    if (!col.sortable) {
      return '';
    }
    const field = col.sortKey ?? col.key;
    const current = this.ordering();
    if (current === field) {
      return 'arrow_upward';
    }
    if (current === `-${field}`) {
      return 'arrow_downward';
    }
    return 'unfold_more';
  }
}
