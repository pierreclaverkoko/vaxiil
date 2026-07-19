import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';

import { ApiError } from '@/core/http/api-error';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { routeParam } from '@/core/router/route-param';
import { BookingServiceSummaryComponent } from '@/features/bookings/booking-service-summary/booking-service-summary';
import { BookingsService } from '@/features/bookings/bookings.service';
import { PaymentsService } from '@/features/bookings/payments.service';
import { ServicesCatalogService } from '@/features/services/services-catalog.service';
import { BookingDetail } from '@/models/booking';
import { ServiceDetail, formatServicePrice } from '@/models/service-catalog';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';

@Component({
  selector: 'app-payment-confirm-page',
  standalone: true,
  imports: [ButtonComponent, BookingServiceSummaryComponent, ErrorStateComponent, TranslatePipe],
  templateUrl: './payment-confirm-page.html',
  styleUrl: './payment-confirm-page.scss',
})
export class PaymentConfirmPageComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly bookings = inject(BookingsService);
  private readonly payments = inject(PaymentsService);
  private readonly catalog = inject(ServicesCatalogService);
  private readonly locale = inject(LocaleService);

  protected readonly booking = signal<BookingDetail | null>(null);
  protected readonly service = signal<ServiceDetail | null>(null);
  protected readonly loading = signal(true);
  protected readonly loadError = signal<string | null>(null);
  protected readonly actionError = signal<string | null>(null);
  protected readonly paying = signal(false);
  protected readonly applyWallet = signal(true);
  protected readonly walletBalance = signal<string | null>(null);
  protected readonly walletCurrency = signal<string | null>(null);

  protected readonly amountLabel = computed(() => {
    const b = this.booking();
    if (!b) {
      return '';
    }
    const amount = Number(b.totalPrice);
    if (!Number.isFinite(amount)) {
      return b.totalPrice;
    }
    return formatServicePrice(amount, b.currencyCode || 'USD');
  });

  protected readonly showFeeBreakdown = computed(() => {
    const b = this.booking();
    return b?.platformFeePayer?.value === 'C' && Number(b.platformFeeAmount) > 0;
  });

  protected readonly baseLabel = computed(() => {
    const b = this.booking();
    if (!b) {
      return '';
    }
    return formatServicePrice(Number(b.basePrice) || 0, b.currencyCode || 'USD');
  });

  protected readonly feeLabel = computed(() => {
    const b = this.booking();
    if (!b) {
      return '';
    }
    return formatServicePrice(Number(b.platformFeeAmount) || 0, b.currencyCode || 'USD');
  });

  protected readonly walletBalanceLabel = computed(() => {
    const bal = this.walletBalance();
    const code = this.walletCurrency();
    if (bal == null || !code) {
      return '';
    }
    const n = Number(bal);
    if (!Number.isFinite(n)) {
      return `${bal} ${code}`;
    }
    return formatServicePrice(n, code);
  });

  protected readonly hasWalletCredit = computed(() => {
    const bal = this.walletBalance();
    return bal != null && Number(bal) > 0;
  });

  async ngOnInit(): Promise<void> {
    const id = routeParam(this.route, 'id');
    if (!id) {
      this.loadError.set('Missing booking id');
      this.loading.set(false);
      return;
    }
    await this.load(id);
  }

  protected onRetry(): void {
    const id = routeParam(this.route, 'id');
    if (id) {
      void this.load(id);
    }
  }

  protected onCancel(): void {
    const b = this.booking();
    if (b) {
      void this.router.navigate(['/bookings', b.id]);
    } else {
      void this.router.navigateByUrl('/bookings');
    }
  }

  protected async onProceed(): Promise<void> {
    const b = this.booking();
    if (!b || this.paying()) {
      return;
    }
    this.actionError.set(null);
    this.paying.set(true);
    try {
      const link = await this.payments.createPaymentLink(b.id, {
        applyWallet: this.applyWallet() && this.hasWalletCredit(),
      });
      if (link.fullyPaid) {
        await this.router.navigate(['/bookings', b.id], {
          queryParams: { paid: 'wallet' },
        });
        return;
      }
      if (!link.url) {
        this.actionError.set(this.locale.t('errors.requestFailed'));
        return;
      }
      window.location.assign(link.url);
    } catch (error) {
      this.actionError.set((error as ApiError).message);
    } finally {
      this.paying.set(false);
    }
  }

  private async load(id: string): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      const booking = await this.bookings.get(id);
      this.booking.set(booking);
      try {
        this.service.set(await this.catalog.getService(booking.serviceId));
      } catch {
        this.service.set(null);
      }
      try {
        const wallet = await this.payments.getWallet();
        const code = (booking.currencyCode || '').toUpperCase();
        const match = wallet.balances.find(
          (row) => row.currencyCode.toUpperCase() === code && Number(row.balance) > 0,
        );
        if (match) {
          this.walletBalance.set(match.balance);
          this.walletCurrency.set(match.currencyCode);
          this.applyWallet.set(true);
        } else {
          this.walletBalance.set(null);
          this.walletCurrency.set(null);
          this.applyWallet.set(false);
        }
      } catch {
        this.walletBalance.set(null);
        this.walletCurrency.set(null);
      }
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    } finally {
      this.loading.set(false);
    }
  }
}
