import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/features/bookings/presentation/utils/booking_schedule_utils.dart';
import 'package:vaxiil_mobile/features/bookings/presentation/widgets/booking_schedule_calendar.dart';
import 'package:vaxiil_mobile/features/services/data/service_catalog_models.dart';
import 'package:vaxiil_mobile/features/services/data/service_catalog_repository.dart';
import 'package:vaxiil_mobile/l10n/app_localizations.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';

/// Result of the open-slots reschedule / pick flow.
class BookingOpenSlotPick {
  const BookingOpenSlotPick({
    required this.startTime,
    required this.endTime,
  });

  final DateTime startTime;
  final DateTime endTime;
}

/// Shows Stitch calendar + open-slots chips; returns the chosen window.
Future<BookingOpenSlotPick?> showBookingOpenSlotsSheet({
  required BuildContext context,
  required String serviceId,
  required int durationMinutes,
  String? excludeBookingId,
  DateTime? initialDate,
  int advanceDays = 365,
}) {
  return showModalBottomSheet<BookingOpenSlotPick>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.backgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return _BookingOpenSlotsSheet(
        serviceId: serviceId,
        durationMinutes: durationMinutes,
        excludeBookingId: excludeBookingId,
        initialDate: initialDate,
        advanceDays: advanceDays,
      );
    },
  );
}

class _BookingOpenSlotsSheet extends StatefulWidget {
  const _BookingOpenSlotsSheet({
    required this.serviceId,
    required this.durationMinutes,
    this.excludeBookingId,
    this.initialDate,
    this.advanceDays = 365,
  });

  final String serviceId;
  final int durationMinutes;
  final String? excludeBookingId;
  final DateTime? initialDate;
  final int advanceDays;

  @override
  State<_BookingOpenSlotsSheet> createState() => _BookingOpenSlotsSheetState();
}

class _BookingOpenSlotsSheetState extends State<_BookingOpenSlotsSheet> {
  late DateTime _focusedMonth;
  DateTime? _selectedDate;
  List<OpenSlotModel> _slots = const [];
  OpenSlotModel? _selectedSlot;
  var _slotsLoading = false;
  Object? _slotsError;
  var _slotsRequestId = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final seed = widget.initialDate != null &&
            !dateOnly(widget.initialDate!).isBefore(dateOnly(now))
        ? dateOnly(widget.initialDate!)
        : dateOnly(now.add(const Duration(days: 1)));
    _focusedMonth = DateTime(seed.year, seed.month);
    _selectedDate = seed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedDate != null) {
        _loadSlots(_selectedDate!);
      }
    });
  }

  bool _daySelectable(DateTime day) {
    final d = dateOnly(day);
    final today = dateOnly(DateTime.now());
    final last = today.add(Duration(days: widget.advanceDays));
    if (d.isBefore(today)) {
      return false;
    }
    if (d.isAfter(last)) {
      return false;
    }
    return true;
  }

  Future<void> _loadSlots(DateTime day) async {
    final token = ++_slotsRequestId;
    setState(() {
      _slotsLoading = true;
      _slotsError = null;
      _slots = const [];
      _selectedSlot = null;
    });
    try {
      final result = await sl<ServiceCatalogRepository>().listOpenSlots(
        widget.serviceId,
        day,
        durationMinutes: widget.durationMinutes,
        excludeBookingId: widget.excludeBookingId,
      );
      if (!mounted || token != _slotsRequestId) {
        return;
      }
      setState(() {
        _slots = result.slots;
        _selectedSlot = result.slots.isNotEmpty ? result.slots.first : null;
        _slotsLoading = false;
      });
    } catch (e) {
      if (!mounted || token != _slotsRequestId) {
        return;
      }
      setState(() {
        _slots = const [];
        _selectedSlot = null;
        _slotsLoading = false;
        _slotsError = e;
      });
    }
  }

  void _confirm() {
    final slot = _selectedSlot;
    if (slot == null) {
      return;
    }
    Navigator.of(context).pop(
      BookingOpenSlotPick(
        startTime: slot.startTime,
        endTime: slot.endTime,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final monthLabel = DateFormat.yMMMM().format(_focusedMonth);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.bookingReschedulePickTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor,
                  ),
            ),
            const SizedBox(height: 16),
            BookingCalendarHeader(
              monthLabel: monthLabel,
              cs: cs,
              onPrev: () {
                setState(() {
                  _focusedMonth =
                      DateTime(_focusedMonth.year, _focusedMonth.month - 1);
                });
              },
              onNext: () {
                setState(() {
                  _focusedMonth =
                      DateTime(_focusedMonth.year, _focusedMonth.month + 1);
                });
              },
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.55,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BookingCalendarMonthGrid(
                      focusedMonth: _focusedMonth,
                      selectedDate: _selectedDate,
                      onSelect: (d) {
                        if (!_daySelectable(d)) {
                          return;
                        }
                        final day = dateOnly(d);
                        setState(() => _selectedDate = day);
                        _loadSlots(day);
                      },
                      daySelectable: _daySelectable,
                      inMonth: (d) => isInMonth(d, _focusedMonth),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.bookingAvailableTime,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryColor,
                          ),
                    ),
                    const SizedBox(height: 12),
                    if (_slotsLoading)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                l10n.bookingSlotsLoading,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: AppTheme.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_slotsError != null)
                      Text(
                        _slotsError is Failure
                            ? (_slotsError! as Failure).message
                            : _slotsError.toString(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: cs.error,
                            ),
                      )
                    else if (_slots.isEmpty)
                      Text(
                        l10n.bookingNoSlotsForDay,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      )
                    else
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final slot in _slots)
                            BookingTimeChip(
                              label: DateFormat.jm().format(slot.localStart),
                              selected: sameOpenSlotStart(
                                _selectedSlot?.startTime,
                                slot.startTime,
                              ),
                              onTap: () =>
                                  setState(() => _selectedSlot = slot),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _selectedSlot == null || _slotsLoading
                  ? null
                  : _confirm,
              child: Text(l10n.bookingRescheduleConfirmSlot),
            ),
          ],
        ),
      ),
    );
  }
}
