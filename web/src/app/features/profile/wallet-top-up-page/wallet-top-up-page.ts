import { Component, OnInit, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { AuthService } from '@/core/auth/auth.service';
import { ApiError } from '@/core/http/api-error';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { PaymentsService } from '@/features/bookings/payments.service';
import { PaymentOperationPayload } from '@/shared/payments/payment-catalog.service';
import { PaymentOperationPanelComponent } from '@/shared/payments/payment-operation-panel/payment-operation-panel';

@Component({
  selector: 'app-wallet-top-up-page',
  standalone: true,
  imports: [PaymentOperationPanelComponent, TranslatePipe],
  templateUrl: './wallet-top-up-page.html',
  styleUrl: './wallet-top-up-page.scss',
})
export class WalletTopUpPageComponent implements OnInit {
  private readonly auth = inject(AuthService);
  private readonly payments = inject(PaymentsService);
  private readonly locale = inject(LocaleService);
  private readonly router = inject(Router);

  protected readonly submitting = signal(false);
  protected readonly error = signal<string | null>(null);
  protected readonly errorTitle = signal<string | null>(null);
  protected readonly countryId = signal<string | null>(null);

  async ngOnInit(): Promise<void> {
    const user = this.auth.currentUser() ?? (await this.auth.fetchProfile());
    if (user.verificationStatus?.value !== 'V') {
      void this.router.navigateByUrl('/profile', { replaceUrl: true });
      return;
    }
    this.countryId.set(user.defaultCountryId ?? null);
  }

  protected async onSubmit(payload: PaymentOperationPayload): Promise<void> {
    if (this.submitting()) {
      return;
    }
    if (!payload.method || !payload.amount || Number(payload.amount) <= 0) {
      this.error.set(this.locale.t('profile.walletTopUpAmount'));
      this.errorTitle.set(this.error());
      return;
    }
    const currency = payload.currencyCode || 'USD';
    this.error.set(null);
    this.errorTitle.set(null);
    this.submitting.set(true);
    try {
      await this.payments.fundWallet(payload.amount, currency, {
        paymentMethodId: payload.method.id,
        accountIdentifier: payload.accountIdentifier || '',
        accountName: payload.accountName,
        details: payload.details,
      });
      void this.router.navigateByUrl('/profile', {
        replaceUrl: true,
        state: { walletTopUpPending: true },
      });
    } catch (err) {
      const api = err as ApiError;
      this.error.set(api.message);
      this.errorTitle.set(api.fullMessage ?? api.message);
    } finally {
      this.submitting.set(false);
    }
  }
}
