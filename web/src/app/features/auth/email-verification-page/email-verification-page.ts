import { Component, OnInit, inject, signal } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';

import { AuthService } from '@/core/auth/auth.service';
import { ApiError } from '@/core/http/api-error';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { ButtonComponent } from '@/shared/ui/button/button';
import { InputComponent } from '@/shared/ui/input/input';

@Component({
  selector: 'app-email-verification-page',
  standalone: true,
  imports: [ButtonComponent, InputComponent, TranslatePipe],
  templateUrl: './email-verification-page.html',
  styleUrl: './email-verification-page.scss',
})
export class EmailVerificationPageComponent implements OnInit {
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  private readonly route = inject(ActivatedRoute);
  private readonly locale = inject(LocaleService);

  protected readonly emailHint = signal('');
  protected readonly challengeId = signal<string | null>(null);
  protected readonly code = signal('');
  protected readonly submitting = signal(false);
  protected readonly formError = signal<string | null>(null);
  protected readonly info = signal<string | null>(null);

  async ngOnInit(): Promise<void> {
    const user = this.auth.currentUser();
    if (user && !user.needsEmailVerification) {
      await this.router.navigateByUrl('/discover');
      return;
    }
    this.emailHint.set(user?.email ?? '');
    await this.sendCode(false);
  }

  protected async sendCode(force = false): Promise<void> {
    if (this.submitting()) {
      return;
    }
    this.submitting.set(true);
    this.formError.set(null);
    try {
      const result = await this.auth.sendEmailVerification({ force });
      this.challengeId.set(result.challengeId);
      if (result.emailHint) {
        this.emailHint.set(result.emailHint);
      }
      this.info.set(this.locale.t('auth.emailVerify.sent'));
    } catch (error) {
      this.formError.set((error as ApiError).message);
    } finally {
      this.submitting.set(false);
    }
  }

  protected async onVerify(): Promise<void> {
    const challengeId = this.challengeId();
    const code = this.code().replace(/\D/g, '');
    if (!challengeId || !code || this.submitting()) {
      this.formError.set(this.locale.t('auth.emailVerify.codeRequired'));
      return;
    }
    this.submitting.set(true);
    this.formError.set(null);
    try {
      await this.auth.verifyEmail(challengeId, code);
      const returnUrl = this.route.snapshot.queryParamMap.get('returnUrl') || '/discover';
      await this.router.navigateByUrl(returnUrl);
    } catch (error) {
      this.formError.set((error as ApiError).message);
    } finally {
      this.submitting.set(false);
    }
  }
}
