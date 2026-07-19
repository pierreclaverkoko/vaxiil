import { Component, OnInit, inject, signal } from '@angular/core';

import { AuthService } from '@/core/auth/auth.service';
import { ApiError } from '@/core/http/api-error';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { ButtonComponent } from '@/shared/ui/button/button';
import { InputComponent } from '@/shared/ui/input/input';

@Component({
  selector: 'app-security-page',
  standalone: true,
  imports: [ButtonComponent, InputComponent, TranslatePipe],
  templateUrl: './security-page.html',
  styleUrl: './security-page.scss',
})
export class SecurityPageComponent implements OnInit {
  private readonly auth = inject(AuthService);
  private readonly locale = inject(LocaleService);

  protected readonly currentPassword = signal('');
  protected readonly newPassword = signal('');
  protected readonly code = signal('');
  protected readonly challengeId = signal<string | null>(null);
  protected readonly sendingCode = signal(false);
  protected readonly saving = signal(false);
  protected readonly formError = signal<string | null>(null);
  protected readonly formSuccess = signal<string | null>(null);
  protected readonly twoFactorEnabled = signal(true);

  ngOnInit(): void {
    this.twoFactorEnabled.set(this.auth.currentUser()?.twoFactorEnabled !== false);
  }

  protected async onSendCode(): Promise<void> {
    if (this.sendingCode()) {
      return;
    }
    this.formError.set(null);
    this.sendingCode.set(true);
    try {
      const result = await this.auth.sendOtp('password_change');
      this.challengeId.set(result.challengeId);
    } catch (error) {
      this.formError.set((error as ApiError).message);
    } finally {
      this.sendingCode.set(false);
    }
  }

  protected async onChangePassword(event: Event): Promise<void> {
    event.preventDefault();
    if (this.saving()) {
      return;
    }
    const challengeId = this.challengeId();
    if (!challengeId || !this.code().trim()) {
      this.formError.set(this.locale.t('profile.securityCode'));
      return;
    }
    this.formError.set(null);
    this.formSuccess.set(null);
    this.saving.set(true);
    try {
      await this.auth.changePassword({
        currentPassword: this.currentPassword(),
        newPassword: this.newPassword(),
        challengeId,
        code: this.code().trim(),
      });
      this.formSuccess.set(this.locale.t('profile.securityPasswordUpdated'));
      this.currentPassword.set('');
      this.newPassword.set('');
      this.code.set('');
      this.challengeId.set(null);
    } catch (error) {
      this.formError.set((error as ApiError).message);
    } finally {
      this.saving.set(false);
    }
  }
}
