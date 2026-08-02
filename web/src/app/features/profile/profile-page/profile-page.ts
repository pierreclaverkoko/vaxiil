import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';

import { AuthService } from '@/core/auth/auth.service';
import { ApiError } from '@/core/http/api-error';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import {
  PaymentsService,
  RefundWalletSummary,
} from '@/features/bookings/payments.service';
import { clearKycSubmitted, resolveKycUiState } from '@/features/profile/kyc-session';
import { AuthUser, authUserDisplayName } from '@/models/auth-user';
import { PaymentOperationPayload } from '@/shared/payments/payment-catalog.service';
import { PaymentOperationPanelComponent } from '@/shared/payments/payment-operation-panel/payment-operation-panel';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';
import { environment } from '../../../../environments/environment';

@Component({
  selector: 'app-profile-page',
  standalone: true,
  imports: [
    RouterLink,
    ButtonComponent,
    ErrorStateComponent,
    PaymentOperationPanelComponent,
    TranslatePipe,
  ],
  templateUrl: './profile-page.html',
  styleUrl: './profile-page.scss',
})
export class ProfilePageComponent implements OnInit {
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  private readonly locale = inject(LocaleService);
  private readonly payments = inject(PaymentsService);

  protected readonly supportEmail = environment.supportEmail;
  protected readonly supportPhone = environment.supportPhone;

  protected readonly user = this.auth.currentUser;
  protected readonly displayName = computed(() => {
    const u = this.user();
    return u ? authUserDisplayName(u) : '';
  });

  protected readonly kycState = computed(() =>
    resolveKycUiState(this.user()?.verificationStatus?.value),
  );

  protected readonly isVerified = computed(() => this.kycState() === 'verified');

  /** Trust Alias master toggle: ON = hide real name (Stitch). */
  protected readonly trustAliasOn = computed(() => !this.showRealName());

  protected readonly verifiedOnLabel = computed(() => {
    const raw = this.user()?.verifiedAt;
    if (!raw) {
      return null;
    }
    try {
      const d = new Date(raw);
      if (Number.isNaN(d.getTime())) {
        return raw;
      }
      return new Intl.DateTimeFormat(undefined, { dateStyle: 'medium' }).format(d);
    } catch {
      return raw;
    }
  });

  protected readonly firstName = signal('');
  protected readonly lastName = signal('');
  protected readonly phone = signal('');
  protected readonly dateOfBirth = signal('');
  protected readonly sex = signal('');
  protected readonly showRealName = signal(false);
  protected readonly showPhoneNumber = signal(false);
  protected readonly showEmail = signal(false);
  protected readonly saving = signal(false);
  protected readonly regenerating = signal(false);
  protected readonly uploading = signal(false);
  protected readonly formError = signal<string | null>(null);
  protected readonly formSuccess = signal<string | null>(null);
  protected readonly loadError = signal<string | null>(null);
  protected readonly showShareDetails = signal(false);
  protected readonly wallet = signal<RefundWalletSummary | null>(null);
  protected readonly showTopUp = signal(false);
  protected readonly topUpSubmitting = signal(false);
  protected readonly topUpError = signal<string | null>(null);
  protected readonly topUpPending = signal(false);

  async ngOnInit(): Promise<void> {
    try {
      const profile = this.user() ?? (await this.auth.fetchProfile());
      this.hydrate(profile);
      if (!profile.trustAlias) {
        await this.auth.ensureTrustAlias();
      }
      if (profile.verificationStatus?.value === 'V' || profile.verificationStatus?.value === 'R') {
        clearKycSubmitted();
      }
      try {
        this.wallet.set(await this.payments.getWallet());
      } catch {
        this.wallet.set(null);
      }
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    }
  }

  protected toggleShareDetails(): void {
    this.showShareDetails.update((v) => !v);
  }

  protected async onTopUpSubmit(payload: PaymentOperationPayload): Promise<void> {
    if (this.topUpSubmitting()) {
      return;
    }
    if (!payload.method || !payload.amount || Number(payload.amount) <= 0) {
      this.topUpError.set(this.locale.t('profile.walletTopUpAmount'));
      return;
    }
    const currency =
      payload.currencyCode ||
      this.wallet()?.balances[0]?.currencyCode ||
      'USD';
    this.topUpError.set(null);
    this.topUpSubmitting.set(true);
    try {
      await this.payments.fundWallet(payload.amount, currency, {
        paymentMethodId: payload.method.id,
        accountIdentifier: payload.accountIdentifier || '',
        accountName: payload.accountName,
        details: payload.details,
      });
      this.topUpPending.set(true);
      this.showTopUp.set(false);
      try {
        this.wallet.set(await this.payments.getWallet());
      } catch {
        /* ignore refresh errors */
      }
    } catch (error) {
      this.topUpError.set((error as ApiError).message);
    } finally {
      this.topUpSubmitting.set(false);
    }
  }

  protected onTrustAliasToggle(event: Event): void {
    const hideIdentity = (event.target as HTMLInputElement).checked;
    this.showRealName.set(!hideIdentity);
    void this.persistProfile();
  }

  protected onShowPhoneChange(event: Event): void {
    this.showPhoneNumber.set((event.target as HTMLInputElement).checked);
    void this.persistProfile();
  }

  protected onShowEmailChange(event: Event): void {
    this.showEmail.set((event.target as HTMLInputElement).checked);
    void this.persistProfile();
  }

  protected async onRegenerateAlias(): Promise<void> {
    if (this.regenerating()) {
      return;
    }
    const ok = window.confirm(this.locale.t('profile.regenerateAliasConfirm'));
    if (!ok) {
      return;
    }
    this.formError.set(null);
    this.formSuccess.set(null);
    this.regenerating.set(true);
    try {
      await this.auth.regenerateTrustAlias();
      this.formSuccess.set(this.locale.t('profile.regenerateAliasSuccess'));
    } catch (error) {
      this.formError.set((error as ApiError).message);
    } finally {
      this.regenerating.set(false);
    }
  }

  private async persistProfile(): Promise<void> {
    if (this.saving()) {
      return;
    }
    this.formError.set(null);
    this.formSuccess.set(null);
    this.saving.set(true);
    try {
      const user = await this.auth.updateProfile({
        show_real_name: this.showRealName(),
        show_phone_number: this.showPhoneNumber(),
        show_email: this.showEmail(),
      });
      this.hydrate(user);
      this.formSuccess.set(this.locale.t('profile.saved'));
    } catch (error) {
      this.formError.set((error as ApiError).message);
    } finally {
      this.saving.set(false);
    }
  }

  protected async onAvatarSelected(event: Event): Promise<void> {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file || this.uploading()) {
      return;
    }
    this.formError.set(null);
    this.formSuccess.set(null);
    this.uploading.set(true);
    try {
      await this.auth.uploadAvatar(file);
      this.formSuccess.set(this.locale.t('profile.avatarUpdated'));
    } catch (error) {
      this.formError.set((error as ApiError).message);
    } finally {
      this.uploading.set(false);
      input.value = '';
    }
  }

  protected async onLogout(): Promise<void> {
    await this.auth.logout();
    await this.router.navigateByUrl('/discover');
  }

  protected onRetry(): void {
    void this.ngOnInit();
  }

  private hydrate(user: AuthUser): void {
    this.firstName.set(user.firstName ?? '');
    this.lastName.set(user.lastName ?? '');
    this.phone.set(user.phone ?? '');
    this.dateOfBirth.set(user.dateOfBirth ?? '');
    this.sex.set(user.sex?.value != null ? String(user.sex.value) : '');
    this.showRealName.set(user.showRealName);
    this.showPhoneNumber.set(user.showPhoneNumber);
    this.showEmail.set(user.showEmail);
  }
}
