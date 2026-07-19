import { Component, input, model, output } from '@angular/core';

export interface SegmentedTab {
  id: string;
  label: string;
  icon?: string;
}

@Component({
  selector: 'app-segmented-tabs',
  standalone: true,
  templateUrl: './segmented-tabs.html',
  styleUrl: './segmented-tabs.scss',
})
export class SegmentedTabsComponent {
  readonly tabs = input<SegmentedTab[]>([]);
  readonly activeId = model('');
  readonly activeChange = output<string>();

  protected select(id: string): void {
    this.activeId.set(id);
    this.activeChange.emit(id);
  }
}
