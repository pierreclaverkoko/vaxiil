import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';

import { AuthService } from '@/core/auth/auth.service';
import { ApiError } from '@/core/http/api-error';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import {
  clearKycSubmitted,
  markKycSubmitted,
  resolveKycUiState,
  wasKycSubmittedThisSession,
} from '@/features/profile/kyc-session';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ChoiceEnumChipComponent } from '@/shared/ui/choice-enum-chip/choice-enum-chip';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';
import { environment } from '../../../../environments/environment';

function kycRedirectOrigin(): string {
  if (!environment.production) {
    const fromEnv = (environment.kycRedirectOrigin || '').trim().replace(/\/$/, '');
    if (fromEnv) {
      return fromEnv;
    }
  }
  return typeof window !== 'undefined' ? window.location.origin : '';
}

@Component({
  selector: 'app-kyc-verify-page',
  standalone: true,
  imports: [ButtonComponent, ChoiceEnumChipComponent, ErrorStateComponent, TranslatePipe],
  templateUrl: './kyc-verify-page.html',
  styleUrl: './kyc-verify-page.scss',
})
export class KycVerifyPageComponent implements OnInit {
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  private readonly route = inject(ActivatedRoute);
  private readonly locale = inject(LocaleService);

  protected readonly user = this.auth.currentUser;
  protected readonly submitting = signal(false);
  protected readonly formError = signal<string | null>(null);
  protected readonly formSuccess = signal<string | null>(null);
  protected readonly loadError = signal<string | null>(null);
  /** Bumps when session flag changes so computed UI state refreshes. */
  private readonly sessionTick = signal(0);

  protected readonly kycState = computed(() => {
    this.sessionTick();
    return resolveKycUiState(
      this.user()?.verificationStatus?.value,
      wasKycSubmittedThisSession() || !!this.formSuccess(),
    );
  });

  protected readonly isVerified = computed(() => this.kycState() === 'verified');

  protected readonly showStartCta = computed(() => {
    const state = this.kycState();
    return state === 'not_verified' || state === 'rejected';
  });

  async ngOnInit(): Promise<void> {
    try {
      if (!this.user()) {
        await this.auth.fetchProfile();
      }
      const isReturn = this.router.url.includes('/profile/verify/return');
      if (isReturn) {
        markKycSubmitted();
        this.sessionTick.update((n) => n + 1);
        const qp = this.route.snapshot.queryParamMap;
        const jwt = qp.get('jwt');
        let expiredRetryStarted = false;
        if (jwt) {
          try {
            await this.auth.completeSumsubReturn({
              jwt,
              status: qp.get('status'),
              sbx: qp.get('sbx'),
            });
          } catch (error) {
            const apiError = error as ApiError;
            if (apiError.code === 'sumsub_redirect_jwt_expired') {
              clearKycSubmitted();
              this.sessionTick.update((n) => n + 1);
              expiredRetryStarted = true;
              await this.onStartVerification();
            } else {
              // Still refresh profile so banners reflect webhook/API state.
              this.formError.set(apiError.message);
              await this.auth.fetchProfile();
            }
          }
        } else {
          await this.auth.fetchProfile();
        }
        if (expiredRetryStarted) {
          return;
        }
        const statusParam = qp.get('status');
        const verification = this.user()?.verificationStatus?.value;
        if (verification === 'V') {
          this.formSuccess.set(this.locale.t('profile.kycReturnOk'));
        } else if (verification === 'R' || statusParam === 'reject') {
          this.formSuccess.set(this.locale.t('profile.kycReturnReject'));
        } else if (statusParam === 'ok') {
          this.formSuccess.set(this.locale.t('profile.kycReturnOk'));
        } else {
          this.formSuccess.set(this.locale.t('profile.kycInReviewHint'));
        }
      }
      const status = this.user()?.verificationStatus?.value;
      if (status === 'V' || status === 'R') {
        clearKycSubmitted();
        this.sessionTick.update((n) => n + 1);
      }
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    }
  }

  protected async onStartVerification(): Promise<void> {
    if (this.submitting() || this.isVerified()) {
      return;
    }
    this.formError.set(null);
    this.formSuccess.set(null);
    this.submitting.set(true);
    try {
      const origin = kycRedirectOrigin();
      const url = await this.auth.createSumsubWebsdkLink({
        successUrl: `${origin}/profile/verify/return?status=ok`,
        rejectUrl: `${origin}/profile/verify/return?status=reject`,
        lang: this.locale.locale(),
      });
      markKycSubmitted();
      this.sessionTick.update((n) => n + 1);
      window.location.assign(url);
    } catch (error) {
      this.formError.set((error as ApiError).message);
      this.submitting.set(false);
    }
  }

  protected onBack(): void {
    void this.router.navigateByUrl('/profile');
  }
}
