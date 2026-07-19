import { DecimalPipe } from '@angular/common';
import { Component, ElementRef, OnInit, computed, inject, signal, viewChild } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';

import { ApiError } from '@/core/http/api-error';
import { AuthService } from '@/core/auth/auth.service';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { routeParam } from '@/core/router/route-param';
import {
  TimeSlot,
  combineDateAndTime,
  dateOnly,
  earliestBookingInstant,
  formatMonthLabel,
  isDayBookable,
  isInMonth,
  isSameCalendarDay,
  lastBookableDate,
  monthGridDays,
  slotTooSoon,
  timeSlotsForService,
} from '@/features/bookings/booking-schedule-utils';
import { BookingServiceSummaryComponent } from '@/features/bookings/booking-service-summary/booking-service-summary';
import { BookingsService } from '@/features/bookings/bookings.service';
import { ServicesCatalogService } from '@/features/services/services-catalog.service';
import { BookingCreatePayload } from '@/models/booking';
import { ServiceDetail, ServiceVariantDetail, formatServicePrice } from '@/models/service-catalog';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';
import { InputComponent } from '@/shared/ui/input/input';

@Component({
  selector: 'app-booking-schedule-page',
  standalone: true,
  imports: [
    DecimalPipe,
    ButtonComponent,
    BookingServiceSummaryComponent,
    ErrorStateComponent,
    InputComponent,
    TranslatePipe,
  ],
  templateUrl: './booking-schedule-page.html',
  styleUrl: './booking-schedule-page.scss',
})
export class BookingSchedulePageComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly catalog = inject(ServicesCatalogService);
  private readonly bookings = inject(BookingsService);
  private readonly locale = inject(LocaleService);
  private readonly auth = inject(AuthService);

  private readonly ctaErrorEl = viewChild<ElementRef<HTMLElement>>('ctaError');

  protected readonly service = signal<ServiceDetail | null>(null);
  protected readonly selectedVariantId = signal<string | null>(null);
  protected readonly focusedMonth = signal(dateOnly(new Date()));
  protected readonly selectedDate = signal<Date | null>(null);
  protected readonly selectedTime = signal<TimeSlot | null>(null);
  protected readonly notes = signal('');
  protected readonly locationType = signal('O');
  protected readonly shareName = signal(false);
  protected readonly sharePhone = signal(false);
  protected readonly shareEmail = signal(false);
  protected readonly loading = signal(true);
  protected readonly submitting = signal(false);
  protected readonly confirmOpen = signal(false);
  protected readonly loadError = signal<string | null>(null);
  protected readonly formError = signal<string | null>(null);

  protected readonly formatPrice = formatServicePrice;

  protected readonly activeVariants = computed(() => {
    const s = this.service();
    return s ? s.variants.filter((v) => v.isActive) : [];
  });

  protected readonly selectedVariant = computed((): ServiceVariantDetail | null => {
    const variants = this.activeVariants();
    const id = this.selectedVariantId();
    if (id) {
      return variants.find((v) => v.id === id) ?? variants[0] ?? null;
    }
    return variants[0] ?? null;
  });

  protected readonly calendarDays = computed(() => monthGridDays(this.focusedMonth()));

  protected readonly monthLabel = computed(() =>
    formatMonthLabel(this.focusedMonth(), this.locale.locale()),
  );

  protected readonly weekdayLabels = computed(() => {
    const base = new Date(2024, 0, 1); // Monday
    return Array.from({ length: 7 }, (_, i) => {
      const d = new Date(base);
      d.setDate(base.getDate() + i);
      return new Intl.DateTimeFormat(this.locale.locale(), { weekday: 'short' }).format(d);
    });
  });

  protected readonly timeSlots = computed((): TimeSlot[] => {
    const s = this.service();
    const day = this.selectedDate();
    if (!s || !day) {
      return [];
    }
    const earliest = earliestBookingInstant(s, new Date());
    return timeSlotsForService(s).filter((slot) => !slotTooSoon(day, slot, earliest));
  });

  protected readonly summaryPrice = computed(() => {
    const s = this.service();
    const v = this.selectedVariant();
    if (!s) {
      return '';
    }
    return formatServicePrice(v?.price ?? s.priceMin, s.currency);
  });

  protected readonly summaryDuration = computed(
    () => this.selectedVariant()?.durationMinutes ?? 60,
  );

  protected readonly requiresNameConsent = computed(
    () =>
      this.service()?.organization.requireClientName === true &&
      !this.auth.currentUser()?.showRealName,
  );

  protected readonly canSubmit = computed(
    () =>
      this.service() != null &&
      this.selectedDate() != null &&
      this.selectedTime() != null &&
      !this.submitting(),
  );

  protected readonly confirmWhenLabel = computed(() => {
    const day = this.selectedDate();
    const slot = this.selectedTime();
    if (!day || !slot) {
      return '';
    }
    const dateLabel = new Intl.DateTimeFormat(this.locale.locale(), {
      weekday: 'short',
      month: 'short',
      day: 'numeric',
    }).format(day);
    return `${dateLabel} · ${slot.label}`;
  });

  async ngOnInit(): Promise<void> {
    const id = routeParam(this.route, 'id');
    if (!id) {
      this.loadError.set('Missing service id');
      this.loading.set(false);
      return;
    }
    await this.load(id);
  }

  protected selectVariant(variantId: string): void {
    this.selectedVariantId.set(variantId);
  }

  protected prevMonth(): void {
    const m = this.focusedMonth();
    this.focusedMonth.set(new Date(m.getFullYear(), m.getMonth() - 1, 1));
  }

  protected nextMonth(): void {
    const m = this.focusedMonth();
    this.focusedMonth.set(new Date(m.getFullYear(), m.getMonth() + 1, 1));
  }

  protected isSelectedDay(day: Date): boolean {
    const sel = this.selectedDate();
    return sel != null && isSameCalendarDay(day, sel);
  }

  protected dayInMonth(day: Date): boolean {
    return isInMonth(day, this.focusedMonth());
  }

  protected isDayEnabled(day: Date): boolean {
    const s = this.service();
    if (!s || !isInMonth(day, this.focusedMonth())) {
      return false;
    }
    return isDayBookable(day, s, new Date());
  }

  protected selectDay(day: Date): void {
    if (!this.isDayEnabled(day)) {
      return;
    }
    this.selectedDate.set(dateOnly(day));
    this.selectedTime.set(null);
  }

  protected selectTime(slot: TimeSlot): void {
    this.selectedTime.set(slot);
  }

  protected onRetry(): void {
    const id = routeParam(this.route, 'id');
    if (id) {
      void this.load(id);
    }
  }

  protected onSubmit(event: Event): void {
    event.preventDefault();
    if (this.submitting()) {
      return;
    }
    if (!this.service() || !this.selectedDate() || !this.selectedTime()) {
      this.setFormError(this.locale.t('bookings.pickDateTimeRequired'));
      return;
    }
    this.formError.set(null);
    this.confirmOpen.set(true);
  }

  protected closeConfirm(): void {
    if (this.submitting()) {
      return;
    }
    this.confirmOpen.set(false);
  }

  protected async confirmBooking(): Promise<void> {
    const s = this.service();
    const day = this.selectedDate();
    const slot = this.selectedTime();
    if (!s || !day || !slot || this.submitting()) {
      return;
    }

    if (this.requiresNameConsent() && !this.shareName()) {
      this.confirmOpen.set(false);
      this.setFormError(this.locale.t('bookings.shareNameRequired'));
      return;
    }

    const start = combineDateAndTime(day, slot);
    const variant = this.selectedVariant();
    const duration = variant?.durationMinutes ?? 60;
    const price = variant?.price ?? s.priceMin;
    const end = new Date(start.getTime() + duration * 60000);

    const payload: BookingCreatePayload = {
      service: s.id,
      total_price: String(price),
      special_requests: this.notes().trim(),
      share_name: this.shareName(),
      share_phone: this.sharePhone(),
      share_email: this.shareEmail(),
      time_slots: [
        {
          start_time: start.toISOString(),
          end_time: end.toISOString(),
          location_type: this.locationType(),
        },
      ],
    };
    if (variant) {
      payload.service_variant = variant.id;
    }

    this.formError.set(null);
    this.submitting.set(true);
    try {
      const booking = await this.bookings.create(payload);
      this.confirmOpen.set(false);
      await this.router.navigate(['/bookings', booking.id, 'confirmation']);
    } catch (error) {
      this.confirmOpen.set(false);
      this.setFormError((error as ApiError).message);
    } finally {
      this.submitting.set(false);
    }
  }

  private setFormError(message: string): void {
    this.formError.set(message);
    queueMicrotask(() => {
      this.ctaErrorEl()?.nativeElement.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    });
  }

  private async load(id: string): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      const detail = await this.catalog.getService(id);
      this.service.set(detail);
      const user = this.auth.currentUser();
      this.shareName.set(user?.showRealName === true);
      this.sharePhone.set(user?.showPhoneNumber === true);
      this.shareEmail.set(user?.showEmail === true);
      const first = detail.variants.find((v) => v.isActive);
      if (first) {
        this.selectedVariantId.set(first.id);
      }
      const now = new Date();
      this.focusedMonth.set(new Date(now.getFullYear(), now.getMonth(), 1));
      const last = lastBookableDate(detail, now);
      const candidate = dateOnly(now);
      if (candidate <= last) {
        this.selectedDate.set(candidate);
      }
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    } finally {
      this.loading.set(false);
    }
  }
}
