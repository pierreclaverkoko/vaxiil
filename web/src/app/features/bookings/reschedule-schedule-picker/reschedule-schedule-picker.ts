import { Component, OnInit, computed, inject, input, output, signal } from '@angular/core';

import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import {
  TimeSlot,
  dateOnly,
  formatApiDate,
  formatMonthLabel,
  isInMonth,
  isSameCalendarDay,
  monthGridDays,
  timeSlotsFromOpenSlotStarts,
} from '@/features/bookings/booking-schedule-utils';
import { ServicesCatalogService } from '@/features/services/services-catalog.service';
import { ButtonComponent } from '@/shared/ui/button/button';

export interface ReschedulePick {
  start: Date;
  end: Date;
}

@Component({
  selector: 'app-reschedule-schedule-picker',
  standalone: true,
  imports: [TranslatePipe, ButtonComponent],
  templateUrl: './reschedule-schedule-picker.html',
  styleUrl: './reschedule-schedule-picker.scss',
})
export class RescheduleSchedulePickerComponent implements OnInit {
  private readonly catalog = inject(ServicesCatalogService);
  private readonly locale = inject(LocaleService);

  readonly serviceId = input.required<string>();
  readonly bookingId = input.required<string>();
  readonly durationMinutes = input(60);
  readonly submitting = input(false);

  readonly picked = output<ReschedulePick>();
  readonly cancelled = output<void>();

  protected readonly focusedMonth = signal(dateOnly(new Date()));
  protected readonly selectedDate = signal<Date | null>(null);
  protected readonly selectedTime = signal<TimeSlot | null>(null);
  protected readonly openSlots = signal<{ start: Date; end: Date }[]>([]);
  protected readonly slotsLoading = signal(false);
  protected readonly loadError = signal<string | null>(null);

  protected readonly calendarDays = computed(() => monthGridDays(this.focusedMonth()));
  protected readonly monthLabel = computed(() =>
    formatMonthLabel(this.focusedMonth(), this.locale.locale()),
  );
  protected readonly weekdayLabels = computed(() => {
    const base = new Date(2024, 0, 1);
    return Array.from({ length: 7 }, (_, i) => {
      const d = new Date(base);
      d.setDate(base.getDate() + i);
      return new Intl.DateTimeFormat(this.locale.locale(), { weekday: 'short' }).format(d);
    });
  });
  protected readonly timeSlots = computed(() =>
    timeSlotsFromOpenSlotStarts(this.openSlots().map((s) => s.start)),
  );

  ngOnInit(): void {
    const today = dateOnly(new Date());
    this.focusedMonth.set(new Date(today.getFullYear(), today.getMonth(), 1));
    this.selectedDate.set(today);
    void this.refreshSlots();
  }

  protected prevMonth(): void {
    const m = this.focusedMonth();
    this.focusedMonth.set(new Date(m.getFullYear(), m.getMonth() - 1, 1));
  }

  protected nextMonth(): void {
    const m = this.focusedMonth();
    this.focusedMonth.set(new Date(m.getFullYear(), m.getMonth() + 1, 1));
  }

  protected dayInMonth(day: Date): boolean {
    return isInMonth(day, this.focusedMonth());
  }

  protected isSelectedDay(day: Date): boolean {
    const sel = this.selectedDate();
    return sel != null && isSameCalendarDay(day, sel);
  }

  protected isDayEnabled(day: Date): boolean {
    if (!this.dayInMonth(day)) {
      return false;
    }
    return dateOnly(day).getTime() >= dateOnly(new Date()).getTime();
  }

  protected selectDay(day: Date): void {
    if (!this.isDayEnabled(day)) {
      return;
    }
    this.selectedDate.set(dateOnly(day));
    this.selectedTime.set(null);
    void this.refreshSlots();
  }

  protected selectTime(slot: TimeSlot): void {
    this.selectedTime.set(slot);
  }

  protected onConfirm(): void {
    const day = this.selectedDate();
    const slot = this.selectedTime();
    if (!day || !slot) {
      return;
    }
    const match = this.openSlots().find(
      (s) => s.start.getHours() === slot.hour && s.start.getMinutes() === slot.minute,
    );
    if (!match) {
      return;
    }
    this.picked.emit({ start: match.start, end: match.end });
  }

  protected onCancel(): void {
    this.cancelled.emit();
  }

  private async refreshSlots(): Promise<void> {
    const day = this.selectedDate();
    const serviceId = this.serviceId();
    if (!day || !serviceId) {
      this.openSlots.set([]);
      return;
    }
    this.slotsLoading.set(true);
    this.loadError.set(null);
    try {
      const result = await this.catalog.listOpenSlots(serviceId, formatApiDate(day), {
        durationMinutes: this.durationMinutes(),
        excludeBookingId: this.bookingId(),
      });
      this.openSlots.set(result.slots.map((s) => ({ start: s.startTime, end: s.endTime })));
    } catch (error) {
      this.openSlots.set([]);
      this.loadError.set(error instanceof Error ? error.message : String(error));
    } finally {
      this.slotsLoading.set(false);
    }
  }
}
