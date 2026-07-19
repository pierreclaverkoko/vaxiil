import { ServiceDetail } from '@/models/service-catalog';

export const BOOKING_SELECTION_ACCENT = '#F57C00';

export interface TimeSlot {
  hour: number;
  minute: number;
  label: string;
  value: string;
}

export function parseApiTimeOfDay(raw: string | null | undefined): {
  hour: number;
  minute: number;
} | null {
  if (raw == null || !raw.trim()) {
    return null;
  }
  const parts = raw.trim().split(':');
  if (parts.length < 2) {
    return null;
  }
  const h = Number.parseInt(parts[0]!, 10);
  const m = Number.parseInt(parts[1]!, 10);
  if (!Number.isFinite(h) || !Number.isFinite(m)) {
    return null;
  }
  return { hour: Math.min(23, Math.max(0, h)), minute: Math.min(59, Math.max(0, m)) };
}

export function generateTimeSlots(
  start: { hour: number; minute: number },
  end: { hour: number; minute: number },
  intervalMinutes = 30,
): TimeSlot[] {
  const out: TimeSlot[] = [];
  let cur = start.hour * 60 + start.minute;
  const endMin = end.hour * 60 + end.minute;
  if (cur > endMin) {
    return out;
  }
  while (cur <= endMin) {
    const hour = Math.floor(cur / 60);
    const minute = cur % 60;
    out.push(makeTimeSlot(hour, minute));
    cur += intervalMinutes;
  }
  return out;
}

export function makeTimeSlot(hour: number, minute: number): TimeSlot {
  const value = `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`;
  const period = hour >= 12 ? 'PM' : 'AM';
  const h12 = hour % 12 === 0 ? 12 : hour % 12;
  const label = `${String(h12).padStart(2, '0')}:${String(minute).padStart(2, '0')} ${period}`;
  return { hour, minute, label, value };
}

export function timeSlotsForService(service: ServiceDetail): TimeSlot[] {
  const start = parseApiTimeOfDay(service.availableStartTime) ?? { hour: 9, minute: 0 };
  const end = parseApiTimeOfDay(service.availableEndTime) ?? { hour: 17, minute: 0 };
  return generateTimeSlots(start, end, 30);
}

export function dateOnly(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

export function isSameCalendarDay(a: Date, b: Date): boolean {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  );
}

export function isInMonth(day: Date, month: Date): boolean {
  return day.getFullYear() === month.getFullYear() && day.getMonth() === month.getMonth();
}

/** Monday-first month grid cells (includes leading/trailing padding days). */
export function monthGridDays(focusedMonth: Date): Date[] {
  const first = new Date(focusedMonth.getFullYear(), focusedMonth.getMonth(), 1);
  const leading = (first.getDay() + 6) % 7; // Monday = 0
  const firstVisible = new Date(first);
  firstVisible.setDate(first.getDate() - leading);
  const dim = new Date(focusedMonth.getFullYear(), focusedMonth.getMonth() + 1, 0).getDate();
  const total = leading + dim;
  const rows = Math.ceil(total / 7);
  const cells = rows * 7;
  return Array.from({ length: cells }, (_, i) => {
    const d = new Date(firstVisible);
    d.setDate(firstVisible.getDate() + i);
    return d;
  });
}

export function lastBookableDate(service: ServiceDetail, now: Date): Date {
  const adv = service.bookingAdvanceDays;
  const today = dateOnly(now);
  if (adv == null || adv <= 0) {
    const d = new Date(today);
    d.setDate(d.getDate() + 365);
    return d;
  }
  const d = new Date(today);
  d.setDate(d.getDate() + adv);
  return d;
}

export function earliestBookingInstant(service: ServiceDetail, now: Date): Date {
  const h = service.minimumBookingHours;
  if (h == null || h <= 0) {
    return now;
  }
  return new Date(now.getTime() + h * 3600000);
}

export function combineDateAndTime(day: Date, slot: TimeSlot): Date {
  return new Date(day.getFullYear(), day.getMonth(), day.getDate(), slot.hour, slot.minute);
}

export function isDayBookable(day: Date, service: ServiceDetail, now: Date): boolean {
  const today = dateOnly(now);
  const d = dateOnly(day);
  if (d < today) {
    return false;
  }
  if (d > lastBookableDate(service, now)) {
    return false;
  }
  return true;
}

export function slotTooSoon(day: Date, slot: TimeSlot, earliest: Date): boolean {
  return combineDateAndTime(day, slot).getTime() < earliest.getTime();
}

export function formatMonthLabel(month: Date, locale: string): string {
  return new Intl.DateTimeFormat(locale, { month: 'long', year: 'numeric' }).format(month);
}
