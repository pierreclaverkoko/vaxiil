import { Component, inject } from '@angular/core';

import { LocaleService, type AppLocale } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';

@Component({
  selector: 'app-language-switcher',
  standalone: true,
  imports: [TranslatePipe],
  template: `
    <label class="lang">
      <span class="lang__label">{{ 'common.language' | t }}</span>
      <select
        class="lang__select"
        [value]="locale.locale()"
        (change)="onChange($event)"
        [attr.aria-label]="'common.language' | t"
      >
        <option value="en">{{ 'common.english' | t }}</option>
        <option value="fr">{{ 'common.french' | t }}</option>
      </select>
    </label>
  `,
  styles: `
    .lang {
      display: inline-flex;
      align-items: center;
      gap: 0.35rem;
      font-size: 0.85rem;
      color: var(--color-on-surface-variant, #4a6350);
    }
    .lang__label {
      position: absolute;
      width: 1px;
      height: 1px;
      overflow: hidden;
      clip: rect(0 0 0 0);
    }
    .lang__select {
      border: none;
      background: transparent;
      color: inherit;
      font: inherit;
      cursor: pointer;
      padding: 0.2rem 0.1rem;
    }
  `,
})
export class LanguageSwitcherComponent {
  protected readonly locale = inject(LocaleService);

  protected onChange(event: Event): void {
    const value = (event.target as HTMLSelectElement).value as AppLocale;
    void this.locale.setLocale(value === 'fr' ? 'fr' : 'en');
  }
}
