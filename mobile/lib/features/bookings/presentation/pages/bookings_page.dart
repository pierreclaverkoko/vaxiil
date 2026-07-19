import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vaxiil_mobile/features/bookings/data/booking_models.dart';
import 'package:vaxiil_mobile/features/bookings/data/bookings_repository.dart';
import 'package:vaxiil_mobile/features/bookings/presentation/widgets/booking_list_widgets.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/themes/vaxiil_text.dart';
import 'package:vaxiil_mobile/shared/utils/responsive.dart';
import 'package:vaxiil_mobile/shared/utils/shell_nav.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_app_drawer.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_frosted_top_bar.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_site_footer.dart';

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
    final expanded = context.isExpandedShell;
    final barHeight = expanded ? 8.0 : topInset + 56;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final upcomingList = sortedUpcomingBookingList(_items);
    final pastList = sortedPastBookingList(_items);

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
                                child: ResponsiveContent(
                                  narrowMaxWidth: 672,
                                  padding: EdgeInsets.only(top: barHeight + 8),
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
                                      BookingListSegmentedTabs(
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
                                  child: ResponsiveContent(
                                    narrowMaxWidth: 672,
                                    child: BookingListEmptyAll(
                                      vt: vt,
                                      cs: cs,
                                      title: 'No bookings yet',
                                      subtitle:
                                          'Browse services and book a session',
                                    ),
                                  ),
                                )
                              else if (_segment == 0 && upcomingList.isEmpty)
                                SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: ResponsiveContent(
                                    narrowMaxWidth: 672,
                                    child: BookingListEmptyTab(
                                      vt: vt,
                                      cs: cs,
                                      message: 'No upcoming bookings',
                                      detail:
                                          'Browse services and book your next '
                                          'session.',
                                    ),
                                  ),
                                )
                              else if (_segment == 1 && pastList.isEmpty)
                                SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: ResponsiveContent(
                                    narrowMaxWidth: 672,
                                    child: BookingListEmptyTab(
                                      vt: vt,
                                      cs: cs,
                                      message: 'No past bookings yet',
                                      detail: 'Completed and cancelled sessions '
                                          'appear here.',
                                    ),
                                  ),
                                )
                              else
                                SliverToBoxAdapter(
                                  child: ResponsiveContent(
                                    narrowMaxWidth: 672,
                                    padding: EdgeInsets.only(
                                      bottom: bottomInset +
                                          (context.isExpandedShell ? 32 : 96),
                                    ),
                                    child: Column(
                                      children: [
                                        for (final b in _segment == 0
                                            ? upcomingList
                                            : pastList)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 20,
                                            ),
                                            child: _segment == 0
                                                ? BookingUpcomingListCard(
                                                    booking: b,
                                                    vt: vt,
                                                    cs: cs,
                                                    confirmedBadgeColor:
                                                        _confirmedBadge,
                                                    stitchOrange: _stitchOrange,
                                                    onViewDetails: () =>
                                                        _openBookingDetail(
                                                          b.id,
                                                        ),
                                                    onReschedule: () =>
                                                        _openServiceBooking(b),
                                                  )
                                                : BookingPastListCard(
                                                    booking: b,
                                                    vt: vt,
                                                    cs: cs,
                                                    onRebook: () =>
                                                        _openServiceBooking(b),
                                                  ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              const SliverToBoxAdapter(
                                child: VaxiilSiteFooter(),
                              ),
                            ],
                          ),
                        ),
            ),
            if (!expanded)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: VaxiilFrostedTopBar(
                  topPadding: topInset,
                  onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                  onAvatarTap: () => context.go(AppRoutes.profile),
                  avatarUrl: user?.avatarUrl,
                  selectedNavIndex: mainShellSelectedIndex(context),
                  onNavTap: (i) => goMainShellBranch(context, i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

