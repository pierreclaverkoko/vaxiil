import { Component, inject, signal, viewChild } from '@angular/core';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';

import { AuthService, LoginOtpChallenge } from '@/core/auth/auth.service';
import { ApiError } from '@/core/http/api-error';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { ButtonComponent } from '@/shared/ui/button/button';
import { InputComponent } from '@/shared/ui/input/input';
import { TurnstileComponent } from '@/shared/ui/turnstile/turnstile';

@Component({
  selector: 'app-login-page',
  standalone: true,
  imports: [
    RouterLink,
    ButtonComponent,
    InputComponent,
    TranslatePipe,
    TurnstileComponent,
  ],
  templateUrl: './login-page.html',
  styleUrl: './login-page.scss',
})
export class LoginPageComponent {
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  private readonly route = inject(ActivatedRoute);
  private readonly locale = inject(LocaleService);

  private readonly turnstile = viewChild(TurnstileComponent);

  protected readonly email = signal('');
  protected readonly password = signal('');
  protected readonly otpCode = signal('');
  protected readonly otpChallenge = signal<LoginOtpChallenge | null>(null);
  protected readonly turnstileToken = signal<string | null>(null);
  protected readonly submitting = signal(false);
  protected readonly formError = signal<string | null>(null);
  protected readonly emailError = signal<string | null>(null);
  protected readonly passwordError = signal<string | null>(null);

  protected onTurnstileToken(token: string | null): void {
    this.turnstileToken.set(token);
  }

  protected async onSubmit(event: Event): Promise<void> {
    event.preventDefault();
    if (this.submitting()) {
      return;
    }

    this.formError.set(null);
    this.emailError.set(null);
    this.passwordError.set(null);

    const token = this.turnstileToken();
    if (!token) {
      this.formError.set(this.locale.t('auth.turnstile.required'));
      return;
    }

    const challenge = this.otpChallenge();
    if (challenge) {
      await this.verifyOtp(challenge, token);
      return;
    }

    const email = this.email().trim();
    const password = this.password();
    if (!email || !password) {
      this.formError.set(this.locale.t('auth.login.required'));
      return;
    }

    this.submitting.set(true);
    try {
      const result = await this.auth.login({ email, password, turnstileToken: token });
      if ('requiresOtp' in result && result.requiresOtp) {
        this.otpChallenge.set(result);
        this.resetTurnstile();
        return;
      }
      await this.navigateAfterLogin();
    } catch (error) {
      this.applyError(error as ApiError);
      this.resetTurnstile();
    } finally {
      this.submitting.set(false);
    }
  }

  private async verifyOtp(challenge: LoginOtpChallenge, token: string): Promise<void> {
    const code = this.otpCode().trim();
    if (!code) {
      this.formError.set(this.locale.t('auth.login.otpRequired'));
      return;
    }
    this.submitting.set(true);
    try {
      await this.auth.verifyLoginOtp(challenge.challengeId, code, token);
      await this.navigateAfterLogin();
    } catch (error) {
      this.applyError(error as ApiError);
      this.resetTurnstile();
    } finally {
      this.submitting.set(false);
    }
  }

  private resetTurnstile(): void {
    this.turnstileToken.set(null);
    this.turnstile()?.reset();
  }

  private async navigateAfterLogin(): Promise<void> {
    const returnUrl = this.route.snapshot.queryParamMap.get('returnUrl');
    const target =
      returnUrl && returnUrl.startsWith('/') && !returnUrl.startsWith('//')
        ? returnUrl
        : '/discover';
    await this.router.navigateByUrl(target);
  }

  private applyError(error: ApiError): void {
    this.formError.set(error.message);
    if (error.fieldErrors['email']?.[0]) {
      this.emailError.set(error.fieldErrors['email'][0]);
    }
    if (error.fieldErrors['password']?.[0]) {
      this.passwordError.set(error.fieldErrors['password'][0]);
    }
  }
}
