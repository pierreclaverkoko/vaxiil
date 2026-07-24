import 'package:flutter/material.dart';
import 'package:vaxiil_mobile/features/bookings/presentation/utils/booking_schedule_utils.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';

/// Stitch calendar month header (title + prev/next).
class BookingCalendarHeader extends StatelessWidget {
  const BookingCalendarHeader({
    required this.monthLabel,
    required this.onPrev,
    required this.onNext,
    required this.cs,
    this.title = 'Select date',
    super.key,
  });

  final String monthLabel;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ColorScheme cs;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryColor,
                ),
          ),
        ),
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          onPressed: onPrev,
          icon: Icon(Icons.chevron_left, color: cs.primary),
        ),
        Text(
          monthLabel,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.textSecondary,
              ),
        ),
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          onPressed: onNext,
          icon: Icon(Icons.chevron_right, color: cs.primary),
        ),
      ],
    );
  }
}

/// Monday-first month grid with orange selected day.
class BookingCalendarMonthGrid extends StatelessWidget {
  const BookingCalendarMonthGrid({
    required this.focusedMonth,
    required this.selectedDate,
    required this.onSelect,
    required this.daySelectable,
    required this.inMonth,
    super.key,
  });

  final DateTime focusedMonth;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onSelect;
  final bool Function(DateTime) daySelectable;
  final bool Function(DateTime) inMonth;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final days = monthGridDays(focusedMonth);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final w in _weekdays)
              Expanded(
                child: Text(
                  w,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 1.2,
                        color: AppTheme.textSecondary.withOpacity(0.55),
                      ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1,
          ),
          itemCount: days.length,
          itemBuilder: (context, i) {
            final d = days[i];
            final inM = inMonth(d);
            final sel =
                selectedDate != null && isSameCalendarDay(d, selectedDate!);
            final can = daySelectable(d);
            final disabled = !inM || !can;
            return Padding(
              padding: const EdgeInsets.all(4),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: disabled ? null : () => onSelect(d),
                  customBorder: const CircleBorder(),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: sel ? kBookingSelectionAccent : Colors.transparent,
                      boxShadow: sel
                          ? [
                              BoxShadow(
                                color:
                                    kBookingSelectionAccent.withOpacity(0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '${d.day}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight:
                                  sel ? FontWeight.w900 : FontWeight.w700,
                              color: disabled
                                  ? AppTheme.textSecondary.withOpacity(0.35)
                                  : sel
                                      ? Colors.white
                                      : AppTheme.textSecondary,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Orange/selected time or location chip.
class BookingTimeChip extends StatelessWidget {
  const BookingTimeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = selected ? Colors.white : AppTheme.primaryColor;
    return Material(
      color: selected ? kBookingSelectionAccent : cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: kBookingSelectionAccent.withOpacity(0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: fg,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
