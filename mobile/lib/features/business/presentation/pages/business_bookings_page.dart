import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/features/bookings/data/booking_models.dart';
import 'package:vaxiil_mobile/features/bookings/data/bookings_repository.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/widgets/soft_card.dart';

/// Bookings for the current user that belong to [organizationId].
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
      final filtered = list
          .where((b) => b.organizationId == widget.organizationId)
          .toList();
      setState(() {
        _items = filtered;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organization bookings'),
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
              : _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const HeroIcon(
                            HeroIcons.calendarDays,
                            style: HeroIconStyle.outline,
                            size: 64,
                            color: AppTheme.primaryVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No bookings for this business yet',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Customer bookings will appear here',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      itemBuilder: (context, i) {
                        final b = _items[i];
                        return SoftCard(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(
                              b.status?.title ?? 'Booking',
                            ),
                            subtitle: Text(
                              '${b.totalPrice} ${b.currencyCode ?? ''}',
                            ),
                            onTap: () => context.push(
                              '${AppRoutes.bookingDetails}?id=${b.id}',
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
