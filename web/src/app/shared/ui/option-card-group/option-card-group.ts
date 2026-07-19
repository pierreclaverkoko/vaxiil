import { Component, input, model, output } from '@angular/core';

export interface OptionCardItem {
  value: string;
  title: string;
  description?: string;
  icon?: string;
}

export type OptionCardMode = 'radio' | 'checkbox';

@Component({
  selector: 'app-option-card-group',
  standalone: true,
  templateUrl: './option-card-group.html',
  styleUrl: './option-card-group.scss',
})
export class OptionCardGroupComponent {
  readonly name = input.required<string>();
  readonly mode = input<OptionCardMode>('radio');
  readonly options = input<OptionCardItem[]>([]);
  readonly compact = input(false);
  /** When set, force a fixed column count (e.g. 2 for schedule options). */
  readonly columns = input<2 | 3 | null>(null);

  /** Selected value for radio mode. */
  readonly value = model('');
  /** Selected values for checkbox / multi mode. */
  readonly values = model<string[]>([]);

  readonly valueChange = output<string>();
  readonly valuesChange = output<string[]>();

  protected isSelected(value: string): boolean {
    if (this.mode() === 'radio') {
      return this.value() === value;
    }
    return this.values().includes(value);
  }

  protected onSelect(value: string): void {
    if (this.mode() === 'radio') {
      this.value.set(value);
      this.valueChange.emit(value);
      return;
    }
    const current = new Set(this.values());
    if (current.has(value)) {
      current.delete(value);
    } else {
      current.add(value);
    }
    const next = [...current];
    this.values.set(next);
    this.valuesChange.emit(next);
  }
}
