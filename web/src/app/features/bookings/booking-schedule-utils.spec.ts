import {
  generateTimeSlots,
  isSameCalendarDay,
  monthGridDays,
  parseApiTimeOfDay,
} from './booking-schedule-utils';

describe('booking-schedule-utils', () => {
  it('parses API times', () => {
    expect(parseApiTimeOfDay('09:00')).toEqual({ hour: 9, minute: 0 });
    expect(parseApiTimeOfDay('9:30:00')).toEqual({ hour: 9, minute: 30 });
    expect(parseApiTimeOfDay('')).toBeNull();
  });

  it('generates half-hour slots', () => {
    const slots = generateTimeSlots({ hour: 9, minute: 0 }, { hour: 10, minute: 0 }, 30);
    expect(slots.map((s) => s.value)).toEqual(['09:00', '09:30', '10:00']);
  });

  it('builds a Monday-first month grid', () => {
    // July 2026 starts on Wednesday
    const days = monthGridDays(new Date(2026, 6, 1));
    expect(days[0]!.getDay()).toBe(1); // Monday
    expect(days.some((d) => d.getDate() === 1 && d.getMonth() === 6)).toBe(true);
  });

  it('compares calendar days', () => {
    expect(
      isSameCalendarDay(new Date(2026, 6, 18, 10), new Date(2026, 6, 18, 23)),
    ).toBe(true);
    expect(isSameCalendarDay(new Date(2026, 6, 18), new Date(2026, 6, 19))).toBe(false);
  });
});
