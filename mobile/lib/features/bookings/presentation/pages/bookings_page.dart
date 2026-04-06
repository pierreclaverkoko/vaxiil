import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:heroicons/heroicons.dart';
import 'package:intl/intl.dart';
import 'package:vaxiil_mobile/core/constants/app_constants.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vaxiil_mobile/features/bookings/data/booking_models.dart';
import 'package:vaxiil_mobile/features/bookings/data/bookings_repository.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/themes/vaxiil_text.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_app_drawer.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_frosted_top_bar.dart';

/// Stitch "My Bookings": frosted bar, Upcoming / Past segmented control, cards.
class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key});

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  List<BookingListItemModel> _items = [];
  Object? _error;
  var _loading = true;
  var _segment = 0;

  static const _stitchOrange = Color(0xFFE67E22);
  static const _confirmedBadge = Color(0xFF1B5E20);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await sl<BookingsRepository>().listMine();
      if (!mounted) {
        return;
      }
      setState(() {
        _items = list;
        _loading = false;
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

  String _err(Object e) => e is Failure ? e.message : e.toString();

  List<BookingListItemModel> _upcoming() {
    final u = _items.where((b) => !b.isPastBooking).toList();
    int sortKey(BookingListItemModel b) {
      final t = b.earliestSlotStart;
      if (t == null) return 1 << 30;
      return t.millisecondsSinceEpoch;
    }

    u.sort((a, b) => sortKey(a).compareTo(sortKey(b)));
    return u;
  }

  List<BookingListItemModel> _past() {
    final p = _items.where((b) => b.isPastBooking).toList();
    int sortKey(BookingListItemModel b) {
      final t = b.earliestSlotStart ?? b.createdAt;
      if (t == null) return 0;
      return -t.millisecondsSinceEpoch;
    }

    p.sort((a, b) => sortKey(a).compareTo(sortKey(b)));
    return p;
  }

  void _openServiceBooking(BookingListItemModel b) {
    if (b.serviceId.isEmpty) return;
    final v = b.serviceVariant?.id;
    final q = v != null && v.isNotEmpty ? '&variantId=$v' : '';
    context.push('${AppRoutes.serviceBooking}?id=${b.serviceId}$q');
  }

  void _openBookingDetail(String id) {
    context.push('${AppRoutes.bookingDetails}?id=$id');
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().state.user;
    final cs = Theme.of(context).colorScheme;
    final vt = VaxiilText.of(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final barHeight = topInset + 56;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final upcomingList = _upcoming();
    final pastList = _past();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark,
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: cs.surface,
      ),
      child: Scaffold(
        key: _scaffoldKey,
        primary: false,
        backgroundColor: AppTheme.backgroundColor,
        drawer: const VaxiilAppDrawer(),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            24,
                            barHeight + 24,
                            24,
                            24,
                          ),
                          children: [
                            Text(
                              _err(_error!),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(color: cs.error),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _load,
                              child: const Text('Retry'),
                            ),
                          ],
                        )
                      : RefreshIndicator(
                          color: cs.primary,
                          onRefresh: _load,
                          child: CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    24,
                                    barHeight + 8,
                                    24,
                                    0,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'My Bookings',
                                        style: vt.greeting.copyWith(
                                          fontSize: 36,
                                          color: cs.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Manage your wellness journey and '
                                        'sessions.',
                                        style: vt.discoverySubtitle,
                                      ),
                                      const SizedBox(height: 24),
                                      _SegmentedTabs(
                                        selected: _segment,
                                        onChanged: (i) =>
                                            setState(() => _segment = i),
                                      ),
                                      const SizedBox(height: 24),
                                    ],
                                  ),
                                ),
                              ),
                              if (_items.isEmpty)
                                SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: _EmptyAll(vt: vt, cs: cs),
                                )
                              else if (_segment == 0 && upcomingList.isEmpty)
                                SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: _EmptyTab(
                                    vt: vt,
                                    cs: cs,
                                    message: 'No upcoming bookings',
                                    detail:
                                        'Browse services and book your next '
                                        'session.',
                                  ),
                                )
                              else if (_segment == 1 && pastList.isEmpty)
                                SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: _EmptyTab(
                                    vt: vt,
                                    cs: cs,
                                    message: 'No past bookings yet',
                                    detail:
                                        'Completed and cancelled sessions '
                                        'appear here.',
                                  ),
                                )
                              else
                                SliverPadding(
                                  padding: EdgeInsets.fromLTRB(
                                    24,
                                    0,
                                    24,
                                    bottomInset + 96,
                                  ),
                                  sliver: SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        final list = _segment == 0
                                            ? upcomingList
                                            : pastList;
                                        final b = list[index];
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 20,
                                          ),
                                          child: _segment == 0
                                              ? _UpcomingCard(
                                                  booking: b,
                                                  vt: vt,
                                                  cs: cs,
                                                  confirmedBadgeColor:
                                                      _confirmedBadge,
                                                  stitchOrange: _stitchOrange,
                                                  onViewDetails: () =>
                                                      _openBookingDetail(b.id),
                                                  onReschedule: () =>
                                                      _openServiceBooking(b),
                                                )
                                              : _PastCard(
                                                  booking: b,
                                                  vt: vt,
                                                  cs: cs,
                                                  onRebook: () =>
                                                      _openServiceBooking(b),
                                                ),
                                        );
                                      },
                                      childCount: _segment == 0
                                          ? upcomingList.length
                                          : pastList.length,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: VaxiilFrostedTopBar(
                topPadding: topInset,
                logoUrl: AppConstants.brandLogoImageUrl,
                onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                onAvatarTap: () => context.go(AppRoutes.profile),
                avatarUrl: user?.avatarUrl,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.selected,
    required this.onChanged,
  });

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegButton(
              label: 'Upcoming',
              selected: selected == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _SegButton(
              label: 'Past',
              selected: selected == 1,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegButton extends StatelessWidget {
  const _SegButton({
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
    final vt = VaxiilText.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? cs.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF141E17).withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: vt.categoryLabel.copyWith(
                fontSize: 15,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({
    required this.booking,
    required this.vt,
    required this.cs,
    required this.confirmedBadgeColor,
    required this.stitchOrange,
    required this.onViewDetails,
    required this.onReschedule,
  });

  final BookingListItemModel booking;
  final VaxiilText vt;
  final ColorScheme cs;
  final Color confirmedBadgeColor;
  final Color stitchOrange;
  final VoidCallback onViewDetails;
  final VoidCallback onReschedule;

  bool get _isConfirmed =>
      booking.status?.value == 'F' || booking.status?.value == 'P';

  bool get _isPending =>
      booking.status?.value == 'Q' || booking.status?.value == 'D';

  @override
  Widget build(BuildContext context) {
    final dateStr = _formatDate(booking.earliestSlotStart);
    final timeStr = _formatTime(booking.earliestSlotStart);
    final badgeColor = _isPending ? stitchOrange : confirmedBadgeColor;
    final tint = _isPending ? stitchOrange : cs.primary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border.all(
                color: cs.outlineVariant.withOpacity(0.35),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    tint.withOpacity(0.07),
                    Colors.transparent,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.spa_outlined,
                        color: cs.primary,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.displayTitle,
                            style: vt.cardTitle.copyWith(fontSize: 20),
                          ),
                          if (booking.displayProviderSubtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              booking.displayProviderSubtitle!,
                              style: vt.discoverySubtitle.copyWith(
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        (booking.status?.title ?? 'Booking').toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      dateStr,
                      style: vt.categoryLabel.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Icon(
                      Icons.schedule,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeStr,
                      style: vt.categoryLabel.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                if (_isPending) ...[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.errorContainer.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: cs.error.withOpacity(0.12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: cs.error,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'ACTION REQUIRED',
                              style: vt.categoryLabel.copyWith(
                                color: cs.error,
                                fontSize: 11,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Complete any steps from your provider before the '
                          'session.',
                          style: vt.discoverySubtitle.copyWith(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                if (_isConfirmed)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onReschedule,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: cs.onSurfaceVariant,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                            side: BorderSide(color: cs.outlineVariant),
                          ),
                          child: Text(
                            'Reschedule',
                            style: vt.bookNow.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: onViewDetails,
                          style: FilledButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          child: const Text('View details'),
                        ),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onViewDetails,
                      style: FilledButton.styleFrom(
                        backgroundColor: stitchOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: const Text('View details'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime? t) {
  if (t == null) return 'Date TBD';
  return DateFormat.yMMMd().format(t.toLocal());
}

String _formatTime(DateTime? t) {
  if (t == null) return '—';
  return DateFormat.jm().format(t.toLocal());
}

class _PastCard extends StatelessWidget {
  const _PastCard({
    required this.booking,
    required this.vt,
    required this.cs,
    required this.onRebook,
  });

  final BookingListItemModel booking;
  final VaxiilText vt;
  final ColorScheme cs;
  final VoidCallback onRebook;

  @override
  Widget build(BuildContext context) {
    final last = booking.earliestSlotStart ?? booking.createdAt;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.psychology_outlined,
                  color: cs.primary.withOpacity(0.55),
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.displayTitle,
                      style: vt.cardTitle.copyWith(
                        fontSize: 20,
                        color: cs.onSurface.withOpacity(0.85),
                      ),
                    ),
                    if (booking.displayProviderSubtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        booking.displayProviderSubtitle!,
                        style: vt.discoverySubtitle.copyWith(fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LAST SESSION',
                      style: vt.categoryLabel.copyWith(
                        fontSize: 11,
                        letterSpacing: 1.5,
                        color: cs.onSurfaceVariant.withOpacity(0.65),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      last != null
                          ? DateFormat.yMMMd().format(last.toLocal())
                          : '—',
                      style: vt.categoryLabel.copyWith(
                        fontSize: 14,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: booking.serviceId.isEmpty ? null : onRebook,
                style: FilledButton.styleFrom(
                  backgroundColor: cs.secondaryContainer,
                  foregroundColor: cs.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.replay, size: 18, color: cs.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Rebook',
                      style: vt.bookNow.copyWith(color: cs.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyAll extends StatelessWidget {
  const _EmptyAll({required this.vt, required this.cs});

  final VaxiilText vt;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HeroIcon(
            HeroIcons.calendarDays,
            style: HeroIconStyle.outline,
            size: 64,
            color: cs.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'No bookings yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Browse services and book a session',
            style: vt.discoverySubtitle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({
    required this.vt,
    required this.cs,
    required this.message,
    required this.detail,
  });

  final VaxiilText vt;
  final ColorScheme cs;
  final String message;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HeroIcon(
            HeroIcons.calendarDays,
            style: HeroIconStyle.outline,
            size: 56,
            color: cs.primary.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            style: vt.discoverySubtitle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
