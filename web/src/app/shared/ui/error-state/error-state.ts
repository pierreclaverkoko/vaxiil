import { Component, computed, inject, input } from '@angular/core';

import { LocaleService } from '@/core/i18n/locale.service';

@Component({
  selector: 'app-error-state',
  standalone: true,
  templateUrl: './error-state.html',
  styleUrl: './error-state.scss',
})
export class ErrorStateComponent {
  private readonly locale = inject(LocaleService);

  readonly title = input<string | undefined>(undefined);
  readonly message = input<string | undefined>(undefined);

  protected readonly resolvedTitle = computed(() => {
    this.locale.locale();
    return this.title() ?? this.locale.t('ui.errorTitle');
  });

  protected readonly resolvedMessage = computed(() => {
    this.locale.locale();
    return this.message() ?? this.locale.t('ui.errorMessage');
  });
}
