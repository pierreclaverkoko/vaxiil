import { Pipe, PipeTransform, inject } from '@angular/core';

import { LocaleService } from '@/core/i18n/locale.service';

@Pipe({
  name: 't',
  standalone: true,
  pure: false,
})
export class TranslatePipe implements PipeTransform {
  private readonly locale = inject(LocaleService);

  transform(key: string, params?: Record<string, string | number>): string {
    // Depend on locale signal so impure pipe refreshes on language change.
    this.locale.locale();
    return this.locale.t(key, params);
  }
}
