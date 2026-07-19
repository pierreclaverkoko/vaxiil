import { Component, computed, inject, input } from '@angular/core';

import { LocaleService } from '@/core/i18n/locale.service';

@Component({
  selector: 'app-empty-state',
  standalone: true,
  templateUrl: './empty-state.html',
  styleUrl: './empty-state.scss',
})
export class EmptyStateComponent {
  private readonly locale = inject(LocaleService);

  readonly title = input<string | undefined>(undefined);
  readonly message = input('');
  readonly icon = input('inbox');

  protected readonly resolvedTitle = computed(() => {
    this.locale.locale();
    return this.title() ?? this.locale.t('ui.emptyTitle');
  });
}
