import { Component, inject, signal } from '@angular/core';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';

import { AuthService } from '@/core/auth/auth.service';
import { ApiError } from '@/core/http/api-error';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { ButtonComponent } from '@/shared/ui/button/button';
import { InputComponent } from '@/shared/ui/input/input';

@Component({
  selector: 'app-login-page',
  standalone: true,
  imports: [RouterLink, ButtonComponent, InputComponent, TranslatePipe],
  templateUrl: './login-page.html',
  styleUrl: './login-page.scss',
})
export class LoginPageComponent {
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  private readonly route = inject(ActivatedRoute);
  private readonly locale = inject(LocaleService);

  protected readonly email = signal('');
  protected readonly password = signal('');
  protected readonly submitting = signal(false);
  protected readonly formError = signal<string | null>(null);
  protected readonly emailError = signal<string | null>(null);
  protected readonly passwordError = signal<string | null>(null);

  protected async onSubmit(event: Event): Promise<void> {
    event.preventDefault();
    if (this.submitting()) {
      return;
    }

    this.formError.set(null);
    this.emailError.set(null);
    this.passwordError.set(null);

    const email = this.email().trim();
    const password = this.password();
    if (!email || !password) {
      this.formError.set(this.locale.t('auth.login.required'));
      return;
    }

    this.submitting.set(true);
    try {
      await this.auth.login({ email, password });
      const returnUrl = this.route.snapshot.queryParamMap.get('returnUrl');
      const target =
        returnUrl && returnUrl.startsWith('/') && !returnUrl.startsWith('//')
          ? returnUrl
          : '/discover';
      await this.router.navigateByUrl(target);
    } catch (error) {
      this.applyError(error as ApiError);
    } finally {
      this.submitting.set(false);
    }
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
