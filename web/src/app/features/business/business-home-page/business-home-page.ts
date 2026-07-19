import { Component } from '@angular/core';

import { ChoiceEnum } from '@/models/choice-enum';
import { ChoiceEnumChipComponent } from '@/shared/ui/choice-enum-chip/choice-enum-chip';
import { DataTableColumn, DataTableComponent } from '@/shared/ui/data-table/data-table';
import { EmptyStateComponent } from '@/shared/ui/empty-state/empty-state';
import { FiltersToolbarComponent } from '@/shared/ui/filters-toolbar/filters-toolbar';
import { BadgeComponent } from '@/shared/ui/badge/badge';

@Component({
  selector: 'app-business-home-page',
  standalone: true,
  imports: [
    EmptyStateComponent,
    FiltersToolbarComponent,
    DataTableComponent,
    ChoiceEnumChipComponent,
    BadgeComponent,
  ],
  templateUrl: './business-home-page.html',
  styleUrl: './business-home-page.scss',
})
export class BusinessHomePageComponent {
  protected readonly columns: DataTableColumn[] = [
    { key: 'service', label: 'Service' },
    { key: 'status', label: 'Status', width: '8rem' },
    { key: 'when', label: 'When', width: '10rem' },
  ];

  protected readonly sampleStatus: ChoiceEnum = {
    value: 'confirmed',
    title: 'Confirmed',
    css: 'success',
  };
}
