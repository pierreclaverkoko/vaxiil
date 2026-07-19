import { Component, OnInit, inject, signal } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';

import { ApiError } from '@/core/http/api-error';
import { routeParam } from '@/core/router/route-param';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { BookingsService } from '@/features/bookings/bookings.service';
import {
  BookingDetail,
  bookingDisplayTitle,
  earliestSlotStart,
  formatBookingWhen,
  isPastBooking,
} from '@/models/booking';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ChoiceEnumChipComponent } from '@/shared/ui/choice-enum-chip/choice-enum-chip';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';

@Component({
  selector: 'app-business-booking-detail-page',
  standalone: true,
  imports: [ButtonComponent, ChoiceEnumChipComponent, ErrorStateComponent, TranslatePipe],
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
  protected readonly rescheduleDate = signal('');
  protected readonly rescheduleTime = signal('');
  protected readonly showRejectReason = signal(false);
  protected readonly rejectReason = signal('');

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
    return formatBookingWhen(start, slot?.endTime ?? null);
  };

  protected readonly statusValue = () => this.booking()?.status?.value ?? '';

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

  protected async onCancel(): Promise<void> {
    const b = this.booking();
    if (!b || this.acting() || this.isPast()) {
      return;
    }
    const reason = window.prompt(this.locale.t('business.bookings.cancelReasonPrompt'), '');
    if (reason === null) {
      return;
    }
    const trimmed = reason.trim();
    if (!trimmed) {
      this.actionError.set(this.locale.t('business.bookings.reasonRequired'));
      return;
    }
    this.actionError.set(null);
    this.actionSuccess.set(null);
    this.acting.set(true);
    try {
      await this.bookings.cancel(b.id, trimmed);
      this.actionSuccess.set(this.locale.t('business.bookings.cancelled'));
      await this.load(b.id);
    } catch (error) {
      this.actionError.set((error as ApiError).message);
    } finally {
      this.acting.set(false);
    }
  }

  protected async onConfirm(): Promise<void> {
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

  protected toggleReschedule(): void {
    this.showReschedule.update((value) => !value);
  }

  protected async onReschedule(event: Event): Promise<void> {
    event.preventDefault();
    const b = this.booking();
    const start = new Date(`${this.rescheduleDate().trim()}T${this.rescheduleTime().trim()}`);
    if (!b || this.rescheduling() || Number.isNaN(start.getTime())) {
      return;
    }
    const existing = b.timeSlots[0];
    const duration =
      b.serviceVariant?.durationMinutes ??
      (existing?.endTime && existing.startTime
        ? Math.round((existing.endTime.getTime() - existing.startTime.getTime()) / 60000)
        : 60);
    this.actionError.set(null);
    this.actionSuccess.set(null);
    this.rescheduling.set(true);
    try {
      await this.bookings.reschedule(b.id, [
        {
          start_time: start.toISOString(),
          end_time: new Date(start.getTime() + duration * 60000).toISOString(),
          location_type: existing?.locationType?.value != null
            ? String(existing.locationType.value)
            : 'O',
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
