import { Component, inject, signal, viewChild } from '@angular/core';
import { RouterLink } from '@angular/router';

import { AuthService } from '@/core/auth/auth.service';
import { ApiError } from '@/core/http/api-error';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { ButtonComponent } from '@/shared/ui/button/button';
import { InputComponent } from '@/shared/ui/input/input';
import { TurnstileComponent } from '@/shared/ui/turnstile/turnstile';

@Component({
  selector: 'app-forgot-password-page',
  standalone: true,
  imports: [
    RouterLink,
    ButtonComponent,
    InputComponent,
    TranslatePipe,
    TurnstileComponent,
  ],
  templateUrl: './forgot-password-page.html',
  styleUrl: './forgot-password-page.scss',
})
export class ForgotPasswordPageComponent {
  private readonly auth = inject(AuthService);
  private readonly locale = inject(LocaleService);
  private readonly turnstile = viewChild(TurnstileComponent);

  protected readonly step = signal<'request' | 'confirm'>('request');
  protected readonly email = signal('');
  protected readonly challengeId = signal('');
  protected readonly code = signal('');
  protected readonly newPassword = signal('');
  protected readonly turnstileToken = signal<string | null>(null);
  protected readonly submitting = signal(false);
  protected readonly formError = signal<string | null>(null);
  protected readonly formSuccess = signal<string | null>(null);

  protected onTurnstileToken(token: string | null): void {
    this.turnstileToken.set(token);
  }

  protected async onRequest(event: Event): Promise<void> {
    event.preventDefault();
    if (this.submitting()) {
      return;
    }
    const email = this.email().trim();
    const token = this.turnstileToken();
    if (!email) {
      this.formError.set(this.locale.t('auth.login.required'));
      return;
    }
    if (!token) {
      this.formError.set(this.locale.t('auth.turnstile.required'));
      return;
    }
    this.formError.set(null);
    this.submitting.set(true);
    try {
      const result = await this.auth.requestPasswordReset(email, token);
      this.challengeId.set(result.challengeId ?? '');
      this.step.set('confirm');
      this.formSuccess.set(this.locale.t('auth.forgot.codeSent'));
      this.resetTurnstile();
    } catch (error) {
      this.formError.set((error as ApiError).message);
      this.resetTurnstile();
    } finally {
      this.submitting.set(false);
    }
  }

  protected async onConfirm(event: Event): Promise<void> {
    event.preventDefault();
    if (this.submitting()) {
      return;
    }
    const token = this.turnstileToken();
    if (!token) {
      this.formError.set(this.locale.t('auth.turnstile.required'));
      return;
    }
    this.formError.set(null);
    this.submitting.set(true);
    try {
      await this.auth.confirmPasswordReset({
        email: this.email().trim(),
        challengeId: this.challengeId(),
        code: this.code().trim(),
        newPassword: this.newPassword(),
        turnstileToken: token,
      });
      this.formSuccess.set(this.locale.t('auth.forgot.resetDone'));
      this.step.set('request');
      this.resetTurnstile();
    } catch (error) {
      this.formError.set((error as ApiError).message);
      this.resetTurnstile();
    } finally {
      this.submitting.set(false);
    }
  }

  private resetTurnstile(): void {
    this.turnstileToken.set(null);
    this.turnstile()?.reset();
  }
}
