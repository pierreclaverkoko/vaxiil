import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/features/bookings/data/booking_models.dart';
import 'package:vaxiil_mobile/features/bookings/data/bookings_repository.dart';
import 'package:vaxiil_mobile/features/bookings/presentation/widgets/booking_list_widgets.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/themes/vaxiil_text.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_site_footer.dart';

/// Bookings for [organizationId] with ongoing / past segments (mirrors My Bookings).
class BusinessBookingsPage extends StatefulWidget {
  const BusinessBookingsPage({required this.organizationId, super.key});

  final String organizationId;

  @override
  State<BusinessBookingsPage> createState() => _BusinessBookingsPageState();
}

class _BusinessBookingsPageState extends State<BusinessBookingsPage> {
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
      final list = await sl<BookingsRepository>().listMine(
        organizationId: widget.organizationId,
      );
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

  void _openBusinessBookingDetail(String bookingId) {
    context.push(
      '${AppRoutes.businessBookingDetail}?id=$bookingId'
      '&organizationId=${widget.organizationId}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vt = VaxiilText.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final upcomingList = sortedUpcomingBookingList(_items);
    final pastList = sortedPastBookingList(_items);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Bookings'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_err(_error!)),
                  ),
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
                          padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Organization bookings',
                                style: vt.greeting.copyWith(
                                  fontSize: 28,
                                  color: cs.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ongoing and past sessions for your business.',
                                style: vt.discoverySubtitle,
                              ),
                              const SizedBox(height: 20),
                              BookingListSegmentedTabs(
                                selected: _segment,
                                onChanged: (i) => setState(() => _segment = i),
                                firstLabel: 'Ongoing',
                                secondLabel: 'Past',
                              ),
                              const SizedBox(height: 20),
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
                              title: 'No bookings for this business yet',
                              subtitle: 'Customer bookings will appear here',
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
                              message: 'No ongoing bookings',
                              detail:
                                  'Upcoming sessions for this business show here.',
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
                              detail:
                                  'Completed and cancelled sessions appear here.',
                            ),
                          ),
                        )
                      else
                        SliverToBoxAdapter(
                          child: ResponsiveContent(
                            narrowMaxWidth: 672,
                            padding: EdgeInsets.only(bottom: bottomInset + 24),
                            child: Column(
                              children: [
                                for (var index = 0;
                                    index <
                                        (_segment == 0
                                            ? upcomingList.length
                                            : pastList.length);
                                    index++)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 20),
                                    child: _segment == 0
                                        ? BookingUpcomingListCard(
                                            booking: upcomingList[index],
                                            vt: vt,
                                            cs: cs,
                                            confirmedBadgeColor: _confirmedBadge,
                                            stitchOrange: _stitchOrange,
                                            onViewDetails: () =>
                                                _openBusinessBookingDetail(
                                                  upcomingList[index].id,
                                                ),
                                            onReschedule: () =>
                                                _openBusinessBookingDetail(
                                                  upcomingList[index].id,
                                                ),
                                          )
                                        : BookingPastListCard(
                                            booking: pastList[index],
                                            vt: vt,
                                            cs: cs,
                                            onRebook: () {
                                              final b = pastList[index];
                                              if (b.serviceId.isEmpty) return;
                                              final v = b.serviceVariant?.id;
                                              final q = v != null &&
                                                      v.isNotEmpty
                                                  ? '&variantId=$v'
                                                  : '';
                                              context.push(
                                                '${AppRoutes.serviceBooking}?id=${b.serviceId}$q',
                                              );
                                            },
                                          ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      const SliverToBoxAdapter(child: VaxiilSiteFooter()),
                    ],
                  ),
                ),
    );
  }
}
