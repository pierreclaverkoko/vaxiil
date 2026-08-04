import { Component, OnInit, inject, signal } from '@angular/core';
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
import {
  BookingDetail,
  bookingDisplayTitle,
  earliestSlotStart,
  formatBookingWhen,
  isPastBooking,
  isRescheduleAwaitingBusiness,
  locationTypeIcon,
  sessionHasStarted,
} from '@/models/booking';
import { formatServicePrice } from '@/models/service-catalog';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ChoiceEnumChipComponent } from '@/shared/ui/choice-enum-chip/choice-enum-chip';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';

@Component({
  selector: 'app-business-booking-detail-page',
  standalone: true,
  imports: [
    ButtonComponent,
    ChoiceEnumChipComponent,
    ErrorStateComponent,
    TranslatePipe,
    RescheduleSchedulePickerComponent,
  ],
  templateUrl: './business-booking-detail-page.html',
  styleUrl: './business-booking-detail-page.scss',
})
export class BusinessBookingDetailPageComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly bookings = inject(BookingsService);
  private readonly locale = inject(LocaleService);

  protected readonly orgId = signal<string | null>(null);
  protected readonly booking = signal<BookingDetail | null>(null);
  protected readonly loading = signal(true);
  protected readonly loadError = signal<string | null>(null);
  protected readonly actionError = signal<string | null>(null);
  protected readonly actionSuccess = signal<string | null>(null);
  protected readonly acting = signal(false);
  protected readonly rescheduling = signal(false);
  protected readonly showReschedule = signal(false);
  protected readonly showRejectReason = signal(false);
  protected readonly rejectReason = signal('');
  protected readonly showCancelForm = signal(false);
  protected readonly cancelReason = signal('');

  protected readonly isPast = () => {
    const b = this.booking();
    return b ? isPastBooking(b) : false;
  };

  protected readonly displayTitle = () => {
    const b = this.booking();
    return b ? bookingDisplayTitle(b, this.locale.t('business.bookings.fallbackTitle')) : '';
  };

  protected readonly whenLabel = () => {
    const b = this.booking();
    if (!b) {
      return '';
    }
    const start = earliestSlotStart(b);
    const slot = b.timeSlots[0];
    return formatBookingWhen(start, slot?.endTime ?? null, this.locale.locale());
  };

  protected readonly statusValue = () => this.booking()?.status?.value ?? '';

  protected readonly showPaidBadge = () => {
    const b = this.booking();
    return !!b && this.statusValue() === 'Q' && b.isPaid;
  };

  protected readonly canConfirm = () => {
    const b = this.booking();
    return !!b && this.statusValue() === 'Q' && b.isPaid && !this.acting();
  };

  protected readonly sessionStarted = () => {
    const b = this.booking();
    return !!b && sessionHasStarted(b);
  };

  protected readonly canComplete = () => {
    return this.statusValue() === 'F' && this.sessionStarted() && !this.acting();
  };

  protected readonly canCancel = () => {
    const v = this.statusValue();
    return (v === 'F' || v === 'P') && !this.isPast();
  };

  protected readonly showRescheduleActions = () => {
    const b = this.booking();
    return !!b && this.statusValue() === 'R' && isRescheduleAwaitingBusiness(b);
  };

  protected readonly canAcceptReschedule = () => {
    const b = this.booking();
    return !!b && this.showRescheduleActions() && b.isPaid && !this.acting();
  };

  protected readonly proposedWhenLabel = () => {
    const proposal = this.booking()?.pendingReschedule;
    const slot = proposal?.timeSlots[0];
    if (!slot) {
      return '';
    }
    return formatBookingWhen(slot.startTime, slot.endTime, this.locale.locale());
  };

  protected readonly venueIcon = () => {
    const b = this.booking();
    return locationTypeIcon(b?.timeSlots[0]?.locationType?.value);
  };

  protected readonly showFeeBreakdown = () => {
    const b = this.booking();
    return !!b && Number(b.platformFeeAmount) > 0;
  };

  protected readonly feeRateLabel = () => {
    const b = this.booking();
    if (!b) {
      return '';
    }
    const rate = Number(b.platformFeeRate);
    if (!Number.isFinite(rate) || rate <= 0) {
      return this.locale.t('bookings.feePlatform');
    }
    return this.locale.t('bookings.feePlatformRate', { rate: rate.toFixed(2) });
  };

  protected readonly baseLabel = () => {
    const b = this.booking();
    if (!b) {
      return '';
    }
    return formatServicePrice(Number(b.basePrice) || 0, b.currencyCode || 'USD', this.locale.locale());
  };

  protected readonly feeLabel = () => {
    const b = this.booking();
    if (!b) {
      return '';
    }
    return formatServicePrice(
      Number(b.platformFeeAmount) || 0,
      b.currencyCode || 'USD',
      this.locale.locale(),
    );
  };

  protected readonly totalLabel = () => {
    const b = this.booking();
    if (!b) {
      return '';
    }
    const amount = Number(b.totalPrice);
    if (!Number.isFinite(amount)) {
      return `${b.totalPrice} ${b.currencyCode}`.trim();
    }
    return formatServicePrice(amount, b.currencyCode || 'USD', this.locale.locale());
  };

  protected readonly netCapturedLabel = () => {
    const b = this.booking();
    const pay = b?.paymentSummary;
    if (!b || !pay) {
      return '';
    }
    const amount = Number(pay.netCaptured);
    const code = pay.currencyCode || b.currencyCode || 'USD';
    if (!Number.isFinite(amount)) {
      return `${pay.netCaptured} ${code}`.trim();
    }
    return formatServicePrice(amount, code, this.locale.locale());
  };

  async ngOnInit(): Promise<void> {
    const orgId = routeParam(this.route, 'orgId');
    const bookingId = routeParam(this.route, 'id');
    this.orgId.set(orgId);

    if (!bookingId) {
      this.loadError.set(this.locale.t('business.bookings.missingId'));
      this.loading.set(false);
      return;
    }
    await this.load(bookingId);
  }

  protected onRetry(): void {
    const bookingId = routeParam(this.route, 'id');
    if (bookingId) {
      void this.load(bookingId);
    }
  }

  protected openCancelForm(): void {
    if (!this.canCancel()) {
      return;
    }
    this.showReschedule.set(false);
    this.showRejectReason.set(false);
    this.cancelReason.set('');
    this.actionError.set(null);
    this.showCancelForm.set(true);
  }

  protected closeCancelForm(): void {
    this.showCancelForm.set(false);
    this.cancelReason.set('');
  }

  protected async submitCancel(): Promise<void> {
    const b = this.booking();
    if (!b || this.acting() || !this.canCancel()) {
      return;
    }
    const trimmed = this.cancelReason().trim();
    if (!trimmed) {
      this.actionError.set(this.locale.t('business.bookings.reasonRequired'));
      return;
    }
    this.actionError.set(null);
    this.actionSuccess.set(null);
    this.acting.set(true);
    try {
      const data = await this.bookings.cancel(b.id, trimmed);
      const refund =
        data['refund'] && typeof data['refund'] === 'object' && !Array.isArray(data['refund'])
          ? (data['refund'] as Record<string, unknown>)
          : null;
      if (refund?.['destination'] === 'wallet' && refund['amount'] != null) {
        this.actionSuccess.set(
          this.locale.t('business.bookings.cancelledWalletCredit', {
            amount: String(refund['amount']),
            currency: String(refund['currency_code'] ?? b.currencyCode ?? ''),
          }),
        );
      } else {
        this.actionSuccess.set(this.locale.t('business.bookings.cancelled'));
      }
      this.showCancelForm.set(false);
      this.cancelReason.set('');
      await this.load(b.id);
    } catch (error) {
      this.actionError.set((error as ApiError).message);
    } finally {
      this.acting.set(false);
    }
  }

  protected async onConfirm(): Promise<void> {
    if (!this.canConfirm()) {
      return;
    }
    await this.runAction('confirm', 'business.bookings.confirmed');
  }

  protected onReject(): void {
    this.rejectReason.set('');
    this.showRejectReason.set(true);
    this.actionError.set(null);
  }

  protected cancelReject(): void {
    this.showRejectReason.set(false);
    this.rejectReason.set('');
  }

  protected async submitReject(): Promise<void> {
    const b = this.booking();
    const reason = this.rejectReason().trim();
    if (!b || this.acting()) {
      return;
    }
    if (!reason) {
      this.actionError.set(this.locale.t('business.bookings.reasonRequired'));
      return;
    }
    this.actionError.set(null);
    this.actionSuccess.set(null);
    this.acting.set(true);
    try {
      await this.bookings.reject(b.id, reason);
      this.showRejectReason.set(false);
      this.rejectReason.set('');
      this.actionSuccess.set(this.locale.t('business.bookings.rejected'));
      await this.load(b.id);
    } catch (error) {
      this.actionError.set((error as ApiError).message);
    } finally {
      this.acting.set(false);
    }
  }

  protected async onComplete(): Promise<void> {
    await this.runAction('complete', 'business.bookings.completed');
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
      this.actionSuccess.set(this.locale.t('business.bookings.rescheduleAccepted'));
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
    if (!confirm(this.locale.t('business.bookings.confirmDeclineReschedule'))) {
      return;
    }
    this.actionError.set(null);
    this.actionSuccess.set(null);
    this.acting.set(true);
    try {
      this.booking.set(await this.bookings.declineReschedule(b.id));
      this.actionSuccess.set(this.locale.t('business.bookings.rescheduleDeclined'));
    } catch (error) {
      this.actionError.set((error as ApiError).message);
    } finally {
      this.acting.set(false);
    }
  }

  protected toggleReschedule(): void {
    this.showReschedule.update((value) => !value);
  }

  protected rescheduleDurationMinutes(): number {
    const b = this.booking();
    if (!b) {
      return 60;
    }
    if (b.serviceVariant?.durationMinutes) {
      return b.serviceVariant.durationMinutes;
    }
    const existing = b.timeSlots[0];
    if (existing?.endTime && existing.startTime) {
      return Math.round((existing.endTime.getTime() - existing.startTime.getTime()) / 60000);
    }
    return 60;
  }

  protected async onReschedulePicked(pick: ReschedulePick): Promise<void> {
    const b = this.booking();
    if (!b || this.rescheduling()) {
      return;
    }
    const existing = b.timeSlots[0];
    this.actionError.set(null);
    this.actionSuccess.set(null);
    this.rescheduling.set(true);
    try {
      await this.bookings.reschedule(b.id, [
        {
          start_time: pick.start.toISOString(),
          end_time: pick.end.toISOString(),
          location_type:
            existing?.locationType?.value != null ? String(existing.locationType.value) : 'O',
        },
      ]);
      this.actionSuccess.set(this.locale.t('business.bookings.rescheduled'));
      this.showReschedule.set(false);
      await this.load(b.id);
    } catch (error) {
      this.actionError.set((error as ApiError).message);
    } finally {
      this.rescheduling.set(false);
    }
  }

  protected onBack(): void {
    const orgId = this.orgId();
    if (orgId) {
      void this.router.navigate(['/business', orgId, 'bookings']);
    }
  }

  private async load(id: string): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      this.booking.set(await this.bookings.get(id));
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    } finally {
      this.loading.set(false);
    }
  }

  private async runAction(
    action: 'confirm' | 'complete',
    successKey: string,
  ): Promise<void> {
    const b = this.booking();
    if (!b || this.acting()) {
      return;
    }
    this.actionError.set(null);
    this.actionSuccess.set(null);
    this.acting.set(true);
    try {
      if (action === 'confirm') {
        await this.bookings.confirm(b.id);
      } else {
        await this.bookings.complete(b.id);
      }
      this.actionSuccess.set(this.locale.t(successKey));
      await this.load(b.id);
    } catch (error) {
      this.actionError.set((error as ApiError).message);
    } finally {
      this.acting.set(false);
    }
  }
}
