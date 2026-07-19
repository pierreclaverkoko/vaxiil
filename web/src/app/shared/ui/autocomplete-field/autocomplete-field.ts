import { Component, computed, input, model, output, signal } from '@angular/core';

import { TranslatePipe } from '@/core/i18n/translate.pipe';

export interface AutocompleteOption {
  id: string;
  label: string;
  description?: string;
}

@Component({
  selector: 'app-autocomplete-field',
  standalone: true,
  imports: [TranslatePipe],
  templateUrl: './autocomplete-field.html',
  styleUrl: './autocomplete-field.scss',
})
export class AutocompleteFieldComponent {
  readonly id = input.required<string>();
  readonly label = input('');
  readonly placeholder = input('');
  readonly disabled = input(false);
  readonly options = input<AutocompleteOption[]>([]);
  readonly loading = input(false);
  readonly emptyLabel = input('ui.autocompleteEmpty');

  readonly query = model('');
  readonly selectedId = model<string | null>(null);
  readonly selectedLabel = model('');

  readonly queryChange = output<string>();
  readonly selectionChange = output<AutocompleteOption | null>();

  protected readonly open = signal(false);

  protected readonly selected = computed(() => {
    const id = this.selectedId();
    if (!id) {
      return null;
    }
    return this.options().find((o) => o.id === id) ?? null;
  });

  protected onInput(event: Event): void {
    const value = (event.target as HTMLInputElement).value;
    this.query.set(value);
    this.selectedId.set(null);
    this.selectedLabel.set('');
    this.open.set(true);
    this.queryChange.emit(value);
    this.selectionChange.emit(null);
  }

  protected onFocus(): void {
    this.open.set(true);
  }

  protected onBlur(): void {
    window.setTimeout(() => this.open.set(false), 150);
  }

  protected pick(option: AutocompleteOption): void {
    this.selectedId.set(option.id);
    this.selectedLabel.set(option.label);
    this.query.set(option.label);
    this.open.set(false);
    this.selectionChange.emit(option);
  }

  protected clear(): void {
    this.query.set('');
    this.selectedId.set(null);
    this.selectedLabel.set('');
    this.queryChange.emit('');
    this.selectionChange.emit(null);
  }
}
