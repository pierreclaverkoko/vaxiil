import { Component, input } from '@angular/core';

export interface DataTableColumn {
  key: string;
  label: string;
  width?: string;
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
}
