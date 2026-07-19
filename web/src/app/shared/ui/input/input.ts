import { Component, computed, input, model, signal } from '@angular/core';

import { TranslatePipe } from '@/core/i18n/translate.pipe';

export type InputType = 'text' | 'email' | 'password' | 'search' | 'tel' | 'url';

@Component({
  selector: 'app-input',
  standalone: true,
  imports: [TranslatePipe],
  templateUrl: './input.html',
  styleUrl: './input.scss',
})
export class InputComponent {
  readonly id = input.required<string>();
  readonly label = input('');
  readonly type = input<InputType>('text');
  readonly placeholder = input('');
  readonly autocomplete = input<string | null>(null);
  readonly disabled = input(false);
  readonly error = input<string | null>(null);
  readonly value = model('');

  /** Exposed for unit tests. */
  readonly passwordVisible = signal(false);

  readonly isPassword = computed(() => this.type() === 'password');

  readonly effectiveType = computed(() => {
    if (this.type() !== 'password') {
      return this.type();
    }
    return this.passwordVisible() ? 'text' : 'password';
  });

  readonly visibilityIcon = computed(() =>
    this.passwordVisible() ? 'visibility_off' : 'visibility',
  );

  togglePasswordVisibility(): void {
    this.passwordVisible.update((v) => !v);
  }
}
