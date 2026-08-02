import { Component, computed, input, model, signal } from '@angular/core';

import { TranslatePipe } from '@/core/i18n/translate.pipe';
import {
  AVAILABLE_HEROICON_NAMES,
  heroiconToMaterialSymbol,
} from '@/shared/ui/icon/heroicon-to-material';

const MAX_VISIBLE = 80;

@Component({
  selector: 'app-icon-autocomplete',
  standalone: true,
  imports: [TranslatePipe],
  templateUrl: './icon-autocomplete.html',
  styleUrl: './icon-autocomplete.scss',
})
export class IconAutocompleteFieldComponent {
  readonly id = input.required<string>();
  readonly label = input('');
  readonly placeholder = input('');
  readonly disabled = input(false);

  /** Heroicon kebab-case name (API value). */
  readonly value = model('');

  protected readonly open = signal(false);
  protected readonly query = signal('');

  protected readonly previewSymbol = computed(() =>
    heroiconToMaterialSymbol(this.value() || this.query()),
  );

  protected readonly filtered = computed(() => {
    const q = this.query().trim().toLowerCase();
    const names = AVAILABLE_HEROICON_NAMES;
    if (!q) {
      return names.slice(0, MAX_VISIBLE);
    }
    return names.filter((name) => name.includes(q)).slice(0, MAX_VISIBLE);
  });

  protected materialFor(name: string): string {
    return heroiconToMaterialSymbol(name);
  }

  protected onInput(event: Event): void {
    const next = (event.target as HTMLInputElement).value;
    this.query.set(next);
    this.value.set(next.trim());
    this.open.set(true);
  }

  protected onFocus(): void {
    this.query.set(this.value());
    this.open.set(true);
  }

  protected onBlur(): void {
    window.setTimeout(() => this.open.set(false), 150);
  }

  protected pick(name: string): void {
    this.value.set(name);
    this.query.set(name);
    this.open.set(false);
  }

  protected clear(): void {
    this.value.set('');
    this.query.set('');
  }
}
