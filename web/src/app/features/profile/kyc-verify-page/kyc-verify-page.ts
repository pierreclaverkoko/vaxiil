import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

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
  private readonly locale = inject(LocaleService);

  protected readonly user = this.auth.currentUser;
  protected readonly idFile = signal<File | null>(null);
  protected readonly selfieFile = signal<File | null>(null);
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

  protected readonly showUploadForm = computed(() => {
    const state = this.kycState();
    return state === 'not_verified' || state === 'rejected';
  });

  async ngOnInit(): Promise<void> {
    try {
      if (!this.user()) {
        await this.auth.fetchProfile();
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

  protected onIdSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    this.idFile.set(input.files?.[0] ?? null);
  }

  protected onSelfieSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    this.selfieFile.set(input.files?.[0] ?? null);
  }

  protected async onSubmit(event: Event): Promise<void> {
    event.preventDefault();
    if (this.submitting() || this.isVerified()) {
      return;
    }
    const id = this.idFile();
    const selfie = this.selfieFile();
    if (!id || !selfie) {
      this.formError.set(this.locale.t('profile.kycFilesRequired'));
      return;
    }
    this.formError.set(null);
    this.formSuccess.set(null);
    this.submitting.set(true);
    try {
      await this.auth.submitVerification(id, selfie);
      markKycSubmitted();
      this.sessionTick.update((n) => n + 1);
      this.formSuccess.set(this.locale.t('profile.kycSubmitted'));
      this.idFile.set(null);
      this.selfieFile.set(null);
    } catch (error) {
      this.formError.set((error as ApiError).message);
    } finally {
      this.submitting.set(false);
    }
  }

  protected onBack(): void {
    void this.router.navigateByUrl('/profile');
  }
}
