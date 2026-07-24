import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';

import { ApiError } from '@/core/http/api-error';
import { routeParam } from '@/core/router/route-param';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { BookingsService } from '@/features/bookings/bookings.service';
import {
  ReschedulePick,
  RescheduleSchedulePickerComponent,
} from '@/features/bookings/reschedule-schedule-picker/reschedule-schedule-picker';
import { ServicesCatalogService } from '@/features/services/services-catalog.service';
import {
  BookingDetail,
  bookingDisplayTitle,
  earliestSlotStart,
  formatBookingWhen,
  isPastBooking,
  isRescheduleAwaitingClient,
  locationTypeIcon,
  practitionerDisplayLine,
} from '@/models/booking';
import { ServiceDetail, formatServicePrice } from '@/models/service-catalog';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';

@Component({
  selector: 'app-booking-detail-page',
  standalone: true,
  imports: [
    ButtonComponent,
    ErrorStateComponent,
    TranslatePipe,
    RescheduleSchedulePickerComponent,
  ],
  templateUrl: './booking-detail-page.html',
  styleUrl: './booking-detail-page.scss',
})
export class BookingDetailPageComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly bookings = inject(BookingsService);
  private readonly catalog = inject(ServicesCatalogService);
  private readonly locale = inject(LocaleService);

  protected readonly booking = signal<BookingDetail | null>(null);
  protected readonly service = signal<ServiceDetail | null>(null);
  protected readonly loading = signal(true);
  protected readonly loadError = signal<string | null>(null);
  protected readonly actionError = signal<string | null>(null);
  protected readonly actionSuccess = signal<string | null>(null);
  protected readonly cancelling = signal(false);
  protected readonly acting = signal(false);
  protected readonly rescheduling = signal(false);
  protected readonly showReschedule = signal(false);

  protected readonly isPast = computed(() => {
    const b = this.booking();
    return b ? isPastBooking(b) : false;
  });

  protected readonly displayTitle = computed(() => {
    const b = this.booking();
    return b ? bookingDisplayTitle(b, this.locale.t('bookings.detail')) : '';
  });

  protected readonly organizationName = computed(() => {
    const b = this.booking();
    if (!b) {
      return '';
    }
    return this.service()?.organization.name || b.organizationName || '';
  });

  protected readonly coverImage = computed(() => this.service()?.primaryImage ?? null);

  protected readonly categoryIcon = computed(
    () =>
      this.service()?.subCategory.category.icon ||
      this.booking()?.serviceCategory?.icon ||
      'spa',
  );

  protected readonly dateLabel = computed(() => {
    const start = this.slotStart();
    if (!start) {
      return '';
    }
    return new Intl.DateTimeFormat(undefined, {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    }).format(start);
  });

  protected readonly timeLabel = computed(() => {
    const start = this.slotStart();
    if (!start) {
      return '';
    }
    const timeFmt = new Intl.DateTimeFormat(undefined, {
      hour: 'numeric',
      minute: '2-digit',
    });
    const end = this.slotEnd();
    if (end) {
      return `${timeFmt.format(start)} – ${timeFmt.format(end)}`;
    }
    return timeFmt.format(start);
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

  protected readonly providerLine = computed(() => {
    const b = this.booking();
    return b ? practitionerDisplayLine(b) : null;
  });

  protected readonly practitionerAvatar = computed(
    () => this.booking()?.practitioner?.avatarUrl ?? null,
  );

  protected readonly statusIsWarning = computed(
    () => this.booking()?.status?.css === 'warning',
  );

  protected readonly totalPriceLabel = computed(() => {
    const b = this.booking();
    if (!b?.totalPrice) {
      return null;
    }
    const amount = Number(b.totalPrice);
    if (!Number.isFinite(amount)) {
      return b.totalPrice;
    }
    return formatServicePrice(amount, b.currencyCode || 'USD');
  });

  protected readonly netPaidLabel = computed(() => {
    const pay = this.booking()?.paymentSummary;
    if (!pay?.netCaptured) {
      return null;
    }
    const amount = Number(pay.netCaptured);
    if (!Number.isFinite(amount)) {
      return pay.netCaptured;
    }
    return formatServicePrice(amount, pay.currencyCode || this.booking()?.currencyCode || 'USD');
  });

  protected readonly locationLabel = computed(
    () => this.booking()?.timeSlots[0]?.locationType?.title ?? '',
  );

  protected readonly locationIcon = computed(() =>
    locationTypeIcon(this.booking()?.timeSlots[0]?.locationType?.value),
  );

  protected readonly showFeeBreakdown = computed(() => {
    const b = this.booking();
    return b?.platformFeePayer?.value === 'C' && Number(b.platformFeeAmount) > 0;
  });

  protected readonly basePriceLabel = computed(() => {
    const b = this.booking();
    if (!b) {
      return null;
    }
    return formatServicePrice(Number(b.basePrice) || 0, b.currencyCode || 'USD');
  });

  protected readonly feeAmountLabel = computed(() => {
    const b = this.booking();
    if (!b) {
      return null;
    }
    return formatServicePrice(Number(b.platformFeeAmount) || 0, b.currencyCode || 'USD');
  });

  protected readonly showRescheduleActions = computed(() => {
    const b = this.booking();
    return !!b && b.status?.value === 'R' && isRescheduleAwaitingClient(b);
  });

  /** Accept only after payment for unpaid business-proposed reschedules. */
  protected readonly canAcceptReschedule = computed(() => {
    const b = this.booking();
    return !!b && this.showRescheduleActions() && b.isPaid;
  });

  protected readonly proposedWhenLabel = computed(() => {
    const slot = this.booking()?.pendingReschedule?.timeSlots[0];
    if (!slot) {
      return '';
    }
    return formatBookingWhen(slot.startTime, slot.endTime, this.locale.locale());
  });

  protected readonly canCancel = computed(() => {
    const b = this.booking();
    if (!b || this.isPast() || b.status?.value === 'R') {
      return false;
    }
    if (b.status?.value === 'Q' && b.isPaid) {
      return false;
    }
    return true;
  });

  protected readonly showPayCta = computed(() => {
    if (this.isPast()) {
      return false;
    }
    const b = this.booking();
    if (!b || b.isPaid) {
      return false;
    }
    if (b.status?.value === 'R' && b.pendingReschedule) {
      return true;
    }
    return b.status?.value === 'Q' || b.status?.value === 'D';
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

  protected toggleReschedule(): void {
    this.showReschedule.update((v) => !v);
  }

  protected onPay(): void {
    const b = this.booking();
    if (!b) {
      return;
    }
    void this.router.navigate(['/bookings', b.id, 'pay']);
  }

  protected onRebook(): void {
    const b = this.booking();
    if (!b?.serviceId) {
      return;
    }
    const slot = b.timeSlots[0];
    const start = earliestSlotStart(b);
    const queryParams: Record<string, string> = {};
    if (b.serviceVariant?.id) {
      queryParams['variantId'] = b.serviceVariant.id;
    }
    if (slot?.locationType?.value) {
      queryParams['location'] = String(slot.locationType.value);
    }
    if (start) {
      const y = start.getFullYear();
      const m = String(start.getMonth() + 1).padStart(2, '0');
      const d = String(start.getDate()).padStart(2, '0');
      queryParams['date'] = `${y}-${m}-${d}`;
      queryParams['time'] = `${String(start.getHours()).padStart(2, '0')}:${String(start.getMinutes()).padStart(2, '0')}`;
    }
    void this.router.navigate(['/services', b.serviceId, 'book'], { queryParams });
  }

  protected async onCancel(): Promise<void> {
    const b = this.booking();
    if (!b || this.cancelling() || !this.canCancel()) {
      return;
    }
    if (!confirm(this.locale.t('bookings.confirmCancel'))) {
      return;
    }
    this.actionError.set(null);
    this.actionSuccess.set(null);
    this.cancelling.set(true);
    try {
      await this.bookings.cancel(b.id);
      this.actionSuccess.set(this.locale.t('bookings.cancelled'));
      await this.load(b.id);
    } catch (error) {
      this.actionError.set((error as ApiError).message);
    } finally {
      this.cancelling.set(false);
    }
  }

  protected async onAcceptReschedule(): Promise<void> {
    const b = this.booking();
    if (!b || this.acting()) {
      return;
    }
    this.actionError.set(null);
    this.actionSuccess.set(null);
    this.acting.set(true);
    try {
      this.booking.set(await this.bookings.acceptReschedule(b.id));
      this.actionSuccess.set(this.locale.t('bookings.rescheduleAccepted'));
    } catch (error) {
      this.actionError.set((error as ApiError).message);
    } finally {
      this.acting.set(false);
    }
  }

  protected async onDeclineReschedule(): Promise<void> {
    const b = this.booking();
    if (!b || this.acting()) {
      return;
    }
    if (!confirm(this.locale.t('bookings.confirmDeclineReschedule'))) {
      return;
    }
    this.actionError.set(null);
    this.actionSuccess.set(null);
    this.acting.set(true);
    try {
      this.booking.set(await this.bookings.declineReschedule(b.id));
      this.actionSuccess.set(this.locale.t('bookings.rescheduleDeclined'));
    } catch (error) {
      this.actionError.set((error as ApiError).message);
    } finally {
      this.acting.set(false);
    }
  }

  protected rescheduleDurationMinutes(): number {
    const b = this.booking();
    if (!b) {
      return 60;
    }
    if (b.serviceVariant?.durationMinutes) {
      return b.serviceVariant.durationMinutes;
    }
    const slot = b.timeSlots[0];
    if (slot?.endTime && slot.startTime) {
      return Math.round((slot.endTime.getTime() - slot.startTime.getTime()) / 60000);
    }
    return 60;
  }

  protected async onReschedulePicked(pick: ReschedulePick): Promise<void> {
    const b = this.booking();
    if (!b || this.rescheduling()) {
      return;
    }
    const locationType = b.timeSlots[0]?.locationType?.value ?? 'O';
    this.actionError.set(null);
    this.actionSuccess.set(null);
    this.rescheduling.set(true);
    try {
      await this.bookings.reschedule(b.id, [
        {
          start_time: pick.start.toISOString(),
          end_time: pick.end.toISOString(),
          location_type: String(locationType),
        },
      ]);
      this.actionSuccess.set(this.locale.t('bookings.rescheduled'));
      this.showReschedule.set(false);
      await this.load(b.id);
    } catch (error) {
      this.actionError.set((error as ApiError).message);
    } finally {
      this.rescheduling.set(false);
    }
  }

  protected onBack(): void {
    void this.router.navigateByUrl('/bookings');
  }

  private slotStart(): Date | null {
    const b = this.booking();
    return b ? earliestSlotStart(b) : null;
  }

  private slotEnd(): Date | null {
    return this.booking()?.timeSlots[0]?.endTime ?? null;
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
