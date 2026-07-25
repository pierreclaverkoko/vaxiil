import { Component, OnInit, inject, signal, viewChild } from '@angular/core';
import { Router, RouterLink } from '@angular/router';

import { AuthService } from '@/core/auth/auth.service';
import { ApiError } from '@/core/http/api-error';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { ButtonComponent } from '@/shared/ui/button/button';
import { InputComponent } from '@/shared/ui/input/input';
import { TurnstileComponent } from '@/shared/ui/turnstile/turnstile';

@Component({
  selector: 'app-register-page',
  standalone: true,
  imports: [
    RouterLink,
    ButtonComponent,
    InputComponent,
    TranslatePipe,
    TurnstileComponent,
  ],
  templateUrl: './register-page.html',
  styleUrl: './register-page.scss',
})
export class RegisterPageComponent implements OnInit {
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  private readonly locale = inject(LocaleService);
  private readonly turnstile = viewChild(TurnstileComponent);

  protected readonly fullName = signal('');
  protected readonly email = signal('');
  protected readonly password = signal('');
  protected readonly passwordConfirm = signal('');
  protected readonly acceptedLegal = signal(false);
  protected readonly termsVersion = signal<string | null>(null);
  protected readonly privacyVersion = signal<string | null>(null);
  protected readonly turnstileToken = signal<string | null>(null);
  protected readonly submitting = signal(false);
  protected readonly formError = signal<string | null>(null);

  async ngOnInit(): Promise<void> {
    try {
      const meta = await this.auth.fetchMetadata();
      this.termsVersion.set(meta.termsVersion);
      this.privacyVersion.set(meta.privacyVersion);
    } catch {
      // Register will fail validation if versions missing
    }
  }

  protected onTurnstileToken(token: string | null): void {
    this.turnstileToken.set(token);
  }

  protected async onSubmit(event: Event): Promise<void> {
    event.preventDefault();
    if (this.submitting()) {
      return;
    }

    this.formError.set(null);
    const email = this.email().trim();
    const password = this.password();
    const passwordConfirm = this.passwordConfirm();
    const name = this.fullName().trim();
    const termsVersion = this.termsVersion();
    const privacyVersion = this.privacyVersion();
    const turnstileToken = this.turnstileToken();

    if (!email || !password || !passwordConfirm) {
      this.formError.set(this.locale.t('auth.register.required'));
      return;
    }
    if (password !== passwordConfirm) {
      this.formError.set(this.locale.t('auth.register.mismatch'));
      return;
    }
    if (!this.acceptedLegal() || !termsVersion || !privacyVersion) {
      this.formError.set(this.locale.t('auth.register.acceptLegalRequired'));
      return;
    }
    if (!turnstileToken) {
      this.formError.set(this.locale.t('auth.turnstile.required'));
      return;
    }

    const parts = name.split(/\s+/).filter(Boolean);
    const firstName = parts[0] ?? '';
    const lastName = parts.slice(1).join(' ');
    const username = email.includes('@') ? email.split('@')[0]! : email;

    this.submitting.set(true);
    try {
      await this.auth.register({
        email,
        username,
        password,
        passwordConfirm,
        firstName,
        lastName,
        acceptedTermsVersion: termsVersion,
        acceptedPrivacyVersion: privacyVersion,
        turnstileToken,
      });
      await this.router.navigateByUrl('/discover');
    } catch (error) {
      this.formError.set((error as ApiError).message);
      this.turnstileToken.set(null);
      this.turnstile()?.reset();
    } finally {
      this.submitting.set(false);
    }
  }
}
