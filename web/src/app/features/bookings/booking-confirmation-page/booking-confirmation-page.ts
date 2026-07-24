import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';

import { ApiError } from '@/core/http/api-error';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { routeParam } from '@/core/router/route-param';
import { BookingServiceSummaryComponent } from '@/features/bookings/booking-service-summary/booking-service-summary';
import { BookingsService } from '@/features/bookings/bookings.service';
import { ServicesCatalogService } from '@/features/services/services-catalog.service';
import { BookingDetail, earliestSlotStart, formatBookingWhen } from '@/models/booking';
import { ServiceDetail, formatServicePrice } from '@/models/service-catalog';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ChoiceEnumChipComponent } from '@/shared/ui/choice-enum-chip/choice-enum-chip';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';

@Component({
  selector: 'app-booking-confirmation-page',
  standalone: true,
  imports: [
    RouterLink,
    ButtonComponent,
    BookingServiceSummaryComponent,
    ChoiceEnumChipComponent,
    ErrorStateComponent,
    TranslatePipe,
  ],
  templateUrl: './booking-confirmation-page.html',
  styleUrl: './booking-confirmation-page.scss',
})
export class BookingConfirmationPageComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly bookings = inject(BookingsService);
  private readonly catalog = inject(ServicesCatalogService);
  private readonly locale = inject(LocaleService);

  protected readonly booking = signal<BookingDetail | null>(null);
  protected readonly service = signal<ServiceDetail | null>(null);
  protected readonly loading = signal(true);
  protected readonly loadError = signal<string | null>(null);

  protected readonly whenLabel = computed(() => {
    const b = this.booking();
    if (!b) {
      return '';
    }
    const start = earliestSlotStart(b);
    return formatBookingWhen(start, b.timeSlots[0]?.endTime ?? null, this.locale.locale());
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
    return formatServicePrice(Number(b.basePrice) || 0, b.currencyCode || 'USD', this.locale.locale());
  });

  protected readonly feeLabel = computed(() => {
    const b = this.booking();
    if (!b) {
      return '';
    }
    return formatServicePrice(
      Number(b.platformFeeAmount) || 0,
      b.currencyCode || 'USD',
      this.locale.locale(),
    );
  });

  protected readonly totalLabel = computed(() => {
    const b = this.booking();
    if (!b) {
      return '';
    }
    const amount = Number(b.totalPrice);
    if (!Number.isFinite(amount)) {
      return b.totalPrice;
    }
    return formatServicePrice(amount, b.currencyCode || 'USD', this.locale.locale());
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

  protected viewBooking(): void {
    const b = this.booking();
    if (b) {
      void this.router.navigate(['/bookings', b.id], { replaceUrl: true });
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
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    } finally {
      this.loading.set(false);
    }
  }
}
