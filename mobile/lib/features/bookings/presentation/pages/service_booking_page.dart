import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:intl/intl.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/features/bookings/data/bookings_repository.dart';
import 'package:vaxiil_mobile/features/bookings/presentation/utils/booking_schedule_utils.dart';
import 'package:vaxiil_mobile/features/services/data/service_catalog_models.dart';
import 'package:vaxiil_mobile/features/services/data/service_catalog_repository.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';

/// Stitch “Booking & Scheduling Refined”: hero, editorial calendar, time chips,
/// summary, cancellation, mint confirm CTA.
class ServiceBookingPage extends StatefulWidget {
  const ServiceBookingPage({
    required this.serviceId,
    this.variantId,
    super.key,
  });

  final String serviceId;
  final String? variantId;

  @override
  State<ServiceBookingPage> createState() => _ServiceBookingPageState();
}

class _ServiceBookingPageState extends State<ServiceBookingPage> {
  final _notes = TextEditingController();
  ServiceDetailModel? _service;
  Object? _error;
  var _loading = true;
  var _submitting = false;

  late DateTime _focusedMonth;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _focusedMonth = DateTime(n.year, n.month);
    _load();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.serviceId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Missing service id';
      });
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final d =
          await sl<ServiceCatalogRepository>().getService(widget.serviceId);
      if (!mounted) {
        return;
      }
      setState(() {
        _service = d;
        _loading = false;
        _applyInitialSelection(d);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _applyInitialSelection(ServiceDetailModel s) {
    final now = DateTime.now();
    final tomorrow = dateOnly(now.add(const Duration(days: 1)));
    _focusedMonth = DateTime(tomorrow.year, tomorrow.month);
    _selectedDate = tomorrow;
    _pickFirstSlotForDay(s, tomorrow);
  }

  void _pickFirstSlotForDay(ServiceDetailModel s, DateTime day) {
    final slots = _slotsForDay(s, day);
    _selectedTime = slots.isNotEmpty ? slots.first : null;
  }

  List<TimeOfDay> _slotsForDay(ServiceDetailModel s, DateTime day) {
    final slots = timeSlotsForService(s);
    final earliest = earliestBookingInstant(s, DateTime.now());
    return slots
        .where(
          (t) => !slotTooSoon(day: day, slot: t, earliest: earliest),
        )
        .toList();
  }

  num _price(ServiceDetailModel s) {
    if (widget.variantId != null && widget.variantId!.isNotEmpty) {
      for (final v in s.variants) {
        if (v.id == widget.variantId) {
          return v.price;
        }
      }
    }
    return s.priceMin;
  }

  int _durationMinutes(ServiceDetailModel s) {
    if (widget.variantId != null && widget.variantId!.isNotEmpty) {
      for (final v in s.variants) {
        if (v.id == widget.variantId) {
          return v.durationMinutes;
        }
      }
    }
    return 60;
  }

  String _categoryLabel(ServiceDetailModel s) {
    final c = s.subCategory.category.name;
    if (c.isNotEmpty) {
      return c;
    }
    return s.subCategory.name;
  }

  bool _daySelectable(ServiceDetailModel s, DateTime day) {
    final d = dateOnly(day);
    final today = dateOnly(DateTime.now());
    final last = dateOnly(lastBookableDate(s, DateTime.now()));
    if (d.isBefore(today)) {
      return false;
    }
    if (d.isAfter(last)) {
      return false;
    }
    return _slotsForDay(s, d).isNotEmpty;
  }

  DateTime? get _start {
    final d = _selectedDate;
    final t = _selectedTime;
    if (d == null || t == null) {
      return null;
    }
    return combineDateAndTime(d, t);
  }

  Future<void> _submit() async {
    final s = _service;
    final start = _start;
    if (s == null || start == null) {
      return;
    }
    setState(() => _submitting = true);
    final end = start.add(Duration(minutes: _durationMinutes(s)));
    final body = <String, dynamic>{
      'service': s.id,
      'total_price': _price(s).toString(),
      'special_requests': _notes.text.trim(),
      'time_slots': [
        {
          'start_time': start.toUtc().toIso8601String(),
          'end_time': end.toUtc().toIso8601String(),
          'location_type': 'O',
        },
      ],
    };
    if (widget.variantId != null && widget.variantId!.isNotEmpty) {
      body['service_variant'] = widget.variantId;
    }
    try {
      final data = await sl<BookingsRepository>().create(body);
      if (!mounted) {
        return;
      }
      final bookingId = data['id']?.toString() ?? '';
      if (bookingId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking requested')),
        );
        context.go(AppRoutes.bookings);
      } else {
        context.go('${AppRoutes.bookingConfirmation}?id=$bookingId');
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is Failure ? e.message : e.toString()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String _err(Object e) => e is Failure ? e.message : e.toString();

  String _cancellationCopy(ServiceDetailModel s) {
    final h = s.cancellationHours;
    if (h != null && h > 0) {
      return 'Cancel for free up to $h hours before your appointment. '
          'Late cancellations may incur a fee.';
    }
    return 'Cancel for free up to 24 hours before your appointment. '
        'Late cancellations may incur a 50% fee.';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final top = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark,
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _err(_error!),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : _service == null
                    ? const SizedBox.shrink()
                    : _buildBody(context, cs, top, _service!),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ColorScheme cs,
    double topPadding,
    ServiceDetailModel s,
  ) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final monthLabel = DateFormat.yMMMM().format(_focusedMonth);
    final slots =
        _selectedDate != null ? _slotsForDay(s, _selectedDate!) : <TimeOfDay>[];

    return Stack(
      fit: StackFit.expand,
      children: [
        CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: SizedBox(height: topPadding + 56 + 24)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _ServiceHeroCard(
                  s: s,
                  categoryLabel: _categoryLabel(s),
                  cs: cs,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _CalendarHeader(
                  monthLabel: monthLabel,
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
                  cs: cs,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _CalendarMonthGrid(
                  focusedMonth: _focusedMonth,
                  selectedDate: _selectedDate,
                  onSelect: (d) {
                    if (!_daySelectable(s, d)) {
                      return;
                    }
                    setState(() {
                      _selectedDate = dateOnly(d);
                      _pickFirstSlotForDay(s, _selectedDate!);
                    });
                  },
                  daySelectable: (d) => _daySelectable(s, d),
                  inMonth: (d) => isInMonth(d, _focusedMonth),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Available time',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryColor,
                      ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(
              child: slots.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'No times available for this day. Pick another date.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                    )
                  : SizedBox(
                      height: 56,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        scrollDirection: Axis.horizontal,
                        itemCount: slots.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final t = slots[i];
                          final sel = _selectedTime == t;
                          return _TimeChip(
                            label: DateFormat.jm().format(
                              DateTime(2000, 1, 1, t.hour, t.minute),
                            ),
                            selected: sel,
                            onTap: () => setState(() => _selectedTime = t),
                          );
                        },
                      ),
                    ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _BookingSummaryCard(
                  serviceName: s.name,
                  priceFormatted: NumberFormat.simpleCurrency(
                    name: s.currency,
                  ).format(_price(s)),
                  durationMinutes: _durationMinutes(s),
                  ratingLabel: s.ratingLabel,
                  cs: cs,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Special requests (optional)',
                    filled: true,
                    fillColor: cs.surfaceContainerLowest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: cs.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: cs.outlineVariant),
                    ),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _CancellationRow(
                  text: _cancellationCopy(s),
                  cs: cs,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: 120 + bottomInset),
            ),
          ],
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: EdgeInsets.only(
                  top: topPadding,
                  left: 24,
                  right: 24,
                  bottom: 16,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor.withOpacity(0.82),
                  boxShadow: AppTheme.editorialShadow,
                ),
                child: Row(
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      onPressed: () => context.pop(),
                      icon: HeroIcon(
                        HeroIcons.arrowLeft,
                        style: HeroIconStyle.outline,
                        color: cs.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Schedule booking',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryColor,
                                ),
                      ),
                    ),
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: cs.surfaceContainerHighest,
                      child: Icon(
                        Icons.person_outline,
                        color: cs.primary,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + bottomInset),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      AppTheme.backgroundColor.withOpacity(0.98),
                      AppTheme.backgroundColor.withOpacity(0.6),
                      AppTheme.backgroundColor.withOpacity(0),
                    ],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.ctaFill,
                        foregroundColor: AppTheme.onCtaFill,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        elevation: 0,
                        shadowColor: const Color(0xFF141E17).withOpacity(0.1),
                      ),
                      onPressed: _submitting || _start == null ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.onCtaFill,
                              ),
                            )
                          : const Text(
                              'Confirm booking',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ServiceHeroCard extends StatelessWidget {
  const _ServiceHeroCard({
    required this.s,
    required this.categoryLabel,
    required this.cs,
  });

  final ServiceDetailModel s;
  final String categoryLabel;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 192,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (s.primaryImage != null)
                CachedNetworkImage(
                  imageUrl: s.primaryImage!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => ColoredBox(
                    color: cs.surfaceContainerHigh,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.primary,
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => ColoredBox(
                    color: cs.surfaceContainerHigh,
                    child: Icon(
                      Icons.spa_outlined,
                      size: 48,
                      color: cs.primary,
                    ),
                  ),
                )
              else
                ColoredBox(
                  color: cs.surfaceContainerHigh,
                  child: Icon(
                    Icons.spa_outlined,
                    size: 48,
                    color: cs.primary,
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.55),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                bottom: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          color: Colors.white.withOpacity(0.22),
                          child: Text(
                            categoryLabel.toUpperCase(),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s.name,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.monthLabel,
    required this.onPrev,
    required this.onNext,
    required this.cs,
  });

  final String monthLabel;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Select date',
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

class _CalendarMonthGrid extends StatelessWidget {
  const _CalendarMonthGrid({
    required this.focusedMonth,
    required this.selectedDate,
    required this.onSelect,
    required this.daySelectable,
    required this.inMonth,
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

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : AppTheme.primaryColor,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingSummaryCard extends StatelessWidget {
  const _BookingSummaryCard({
    required this.serviceName,
    required this.priceFormatted,
    required this.durationMinutes,
    required this.ratingLabel,
    required this.cs,
  });

  final String serviceName;
  final String priceFormatted;
  final int durationMinutes;
  final String? ratingLabel;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'BOOKING SUMMARY',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: AppTheme.primaryColor,
                ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Service',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      serviceName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Price',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    priceFormatted,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryColor,
                        ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(
            height: 1,
            color: AppTheme.primaryColor.withOpacity(0.08),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.schedule_outlined, size: 22, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                '$durationMinutes minutes',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (ratingLabel != null) ...[
                const SizedBox(width: 24),
                Icon(Icons.star_rounded, size: 22, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  '$ratingLabel rating',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CancellationRow extends StatelessWidget {
  const _CancellationRow({
    required this.text,
    required this.cs,
  });

  final String text;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 22, color: cs.tertiary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cancellation policy',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.45,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
