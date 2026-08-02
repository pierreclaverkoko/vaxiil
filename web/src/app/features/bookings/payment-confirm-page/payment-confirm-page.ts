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
import { BookingDetail, earliestSlotStart, formatBookingWhen } from '@/models/booking';
import { ServiceDetail, formatServicePrice } from '@/models/service-catalog';
import { PaymentOperationPayload } from '@/shared/payments/payment-catalog.service';
import { PaymentOperationPanelComponent } from '@/shared/payments/payment-operation-panel/payment-operation-panel';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';

@Component({
  selector: 'app-payment-confirm-page',
  standalone: true,
  imports: [
    ButtonComponent,
    BookingServiceSummaryComponent,
    ErrorStateComponent,
    PaymentOperationPanelComponent,
    TranslatePipe,
  ],
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
  protected readonly pendingCollect = signal(false);
  protected readonly applyEscrow = signal(true);
  protected readonly walletBalance = signal<string>('0');
  protected readonly walletCurrency = signal<string | null>(null);

  protected readonly amountLabel = computed(() => {
    const b = this.booking();
    if (!b) {
      return '';
    }
    const inscription = Number(b.inscriptionFeeAmount) || 0;
    const amount = (Number(b.totalPrice) || 0) + inscription;
    if (!Number.isFinite(amount)) {
      return b.totalPrice;
    }
    return formatServicePrice(amount, b.currencyCode || 'USD');
  });

  protected readonly showInscriptionFee = computed(() => {
    const b = this.booking();
    return !!b && Number(b.inscriptionFeeAmount) > 0;
  });

  protected readonly inscriptionLabel = computed(() => {
    const b = this.booking();
    if (!b) {
      return '';
    }
    return formatServicePrice(Number(b.inscriptionFeeAmount) || 0, b.currencyCode || 'USD');
  });

  protected readonly inscriptionNote = computed(() => {
    const note = this.booking()?.paymentSummary?.inscriptionFeeNote?.trim();
    if (note) {
      return note;
    }
    return this.locale.t('bookings.inscriptionFeeHint');
  });

  protected readonly showFeeBreakdown = computed(() => {
    const b = this.booking();
    return b?.platformFeePayer?.value === 'C' && Number(b.platformFeeAmount) > 0;
  });

  protected readonly feeRateLabel = computed(() => {
    const b = this.booking();
    if (!b) {
      return '';
    }
    const rate = Number(b.platformFeeRate);
    if (!Number.isFinite(rate) || rate <= 0) {
      return this.locale.t('bookings.feePlatform');
    }
    return this.locale.t('bookings.feePlatformRate', { rate: rate.toFixed(2) });
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
    const code = this.walletCurrency() || this.booking()?.currencyCode || 'USD';
    const n = Number(bal);
    if (!Number.isFinite(n)) {
      return `${bal} ${code}`;
    }
    return formatServicePrice(n, code);
  });

  protected readonly escrowAppliedAmount = computed(() => {
    const b = this.booking();
    if (!b || !this.applyEscrow()) {
      return 0;
    }
    const inscription = Number(b.inscriptionFeeAmount) || 0;
    const total = (Number(b.totalPrice) || 0) + inscription;
    const bal = Number(this.walletBalance()) || 0;
    return Math.min(total, Math.max(0, bal));
  });

  protected readonly cardAmount = computed(() => {
    const b = this.booking();
    if (!b) {
      return 0;
    }
    const inscription = Number(b.inscriptionFeeAmount) || 0;
    const total = (Number(b.totalPrice) || 0) + inscription;
    return Math.max(0, total - this.escrowAppliedAmount());
  });

  protected readonly needsExternalCollect = computed(() => this.cardAmount() > 0.009);

  protected readonly escrowAppliedLabel = computed(() => {
    const code = this.walletCurrency() || this.booking()?.currencyCode || 'USD';
    return formatServicePrice(this.escrowAppliedAmount(), code);
  });

  protected readonly cardAmountLabel = computed(() => {
    const code = this.walletCurrency() || this.booking()?.currencyCode || 'USD';
    return formatServicePrice(this.cardAmount(), code);
  });

  protected readonly whenLabel = computed(() => {
    const b = this.booking();
    if (!b) {
      return '';
    }
    return formatBookingWhen(
      earliestSlotStart(b),
      b.timeSlots[0]?.endTime ?? null,
      this.locale.locale(),
    );
  });

  protected readonly locationLabel = computed(() => {
    const slot = this.booking()?.timeSlots[0];
    return slot?.locationType?.title ?? '';
  });

  protected readonly canApplyEscrow = computed(() => Number(this.walletBalance()) > 0);

  protected toggleEscrow(): void {
    if (!this.canApplyEscrow()) {
      return;
    }
    this.applyEscrow.update((value) => !value);
  }

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
      void this.router.navigate(['/bookings', b.id], { replaceUrl: true });
    } else {
      void this.router.navigateByUrl('/bookings', { replaceUrl: true });
    }
  }

  protected async onProceed(): Promise<void> {
    const b = this.booking();
    if (!b || this.paying() || this.needsExternalCollect()) {
      return;
    }
    this.actionError.set(null);
    this.paying.set(true);
    try {
      const link = await this.payments.collectForBooking(b.id, {
        applyWallet: this.applyEscrow() && this.escrowAppliedAmount() > 0,
      });
      if (link.fullyPaid) {
        await this.router.navigate(['/bookings', b.id], {
          queryParams: { paid: 'escrow' },
          replaceUrl: true,
        });
        return;
      }
      this.actionError.set(this.locale.t('errors.requestFailed'));
    } catch (error) {
      this.actionError.set((error as ApiError).message);
    } finally {
      this.paying.set(false);
    }
  }

  protected async onCollect(payload: PaymentOperationPayload): Promise<void> {
    const b = this.booking();
    if (!b || this.paying() || !payload.method) {
      return;
    }
    this.actionError.set(null);
    this.paying.set(true);
    try {
      const result = await this.payments.collectForBooking(b.id, {
        applyWallet: this.applyEscrow() && this.escrowAppliedAmount() > 0,
        destination: {
          paymentMethodId: payload.method.id,
          accountIdentifier: payload.accountIdentifier || '',
          accountName: payload.accountName,
          details: payload.details,
        },
      });
      if (result.fullyPaid) {
        await this.router.navigate(['/bookings', b.id], {
          queryParams: { paid: 'escrow' },
          replaceUrl: true,
        });
        return;
      }
      this.pendingCollect.set(true);
      if (result.merchantReference) {
        void this.pollUntilPaid(b.id, result.merchantReference);
      }
    } catch (error) {
      this.actionError.set((error as ApiError).message);
    } finally {
      this.paying.set(false);
    }
  }

  private async pollUntilPaid(bookingId: string, reference: string): Promise<void> {
    for (let i = 0; i < 40; i++) {
      await new Promise((r) => setTimeout(r, 3000));
      try {
        const txn = await this.payments.getTransaction(reference);
        if (txn.status === 'S') {
          await this.router.navigate(['/bookings', bookingId], {
            queryParams: { paid: '1' },
            replaceUrl: true,
          });
          return;
        }
        if (txn.status === 'F' || txn.status === 'X') {
          this.pendingCollect.set(false);
          this.actionError.set(this.locale.t('errors.requestFailed'));
          return;
        }
      } catch {
        /* keep polling */
      }
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
        const match =
          wallet.balances.find((row) => row.currencyCode.toUpperCase() === code) ??
          wallet.balances[0] ??
          null;
        if (match) {
          this.walletBalance.set(match.balance);
          this.walletCurrency.set(match.currencyCode);
          this.applyEscrow.set(Number(match.balance) > 0);
        } else {
          this.walletBalance.set('0');
          this.walletCurrency.set(booking.currencyCode || 'USD');
          this.applyEscrow.set(false);
        }
      } catch {
        this.walletBalance.set('0');
        this.walletCurrency.set(booking.currencyCode || 'USD');
        this.applyEscrow.set(false);
      }
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    } finally {
      this.loading.set(false);
    }
  }
}
