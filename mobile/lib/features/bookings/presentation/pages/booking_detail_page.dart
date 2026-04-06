import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:intl/intl.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/features/bookings/data/booking_models.dart';
import 'package:vaxiil_mobile/features/bookings/data/bookings_repository.dart';
import 'package:vaxiil_mobile/features/services/data/service_catalog_repository.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/widgets/soft_card.dart';

/// Full booking detail (retrieve + cancel).
class BookingDetailPage extends StatefulWidget {
  const BookingDetailPage({required this.bookingId, super.key});

  final String bookingId;

  @override
  State<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage> {
  BookingDetailModel? _booking;
  String? _serviceName;
  Object? _error;
  var _loading = true;
  var _cancelling = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.bookingId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Missing booking id';
      });
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final b = await sl<BookingsRepository>().get(widget.bookingId);
      String? name;
      if (b.serviceId.isNotEmpty) {
        try {
          final detail =
              await sl<ServiceCatalogRepository>().getService(b.serviceId);
          name = detail.name;
        } catch (_) {
          name = null;
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _booking = b;
        _serviceName = name;
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

  bool get _canCancel {
    final s = _booking?.status?.value;
    if (s == null) {
      return false;
    }
    const terminal = {'M', 'X', 'N'};
    return !terminal.contains(s);
  }

  Future<void> _confirmCancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel booking'),
        content: const Text(
          'Are you sure you want to cancel this booking?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) {
      return;
    }
    setState(() => _cancelling = true);
    try {
      await sl<BookingsRepository>().cancel(widget.bookingId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking cancelled')),
      );
      await _load();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_err(e))),
      );
    } finally {
      if (mounted) {
        setState(() => _cancelling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
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
              : _booking == null
                  ? const SizedBox.shrink()
                  : _BookingBody(
                      booking: _booking!,
                      serviceName: _serviceName,
                      canCancel: _canCancel,
                      cancelling: _cancelling,
                      onCancel: _confirmCancel,
                    ),
    );
  }
}

class _BookingBody extends StatelessWidget {
  const _BookingBody({
    required this.booking,
    required this.serviceName,
    required this.canCancel,
    required this.cancelling,
    required this.onCancel,
  });

  final BookingDetailModel booking;
  final String? serviceName;
  final bool canCancel;
  final bool cancelling;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd().add_jm();
    final currency = booking.currencyCode ?? 'USD';
    final price = NumberFormat.simpleCurrency(name: currency)
        .format(double.tryParse(booking.totalPrice) ?? 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SoftCard(
            padding: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.status?.title ?? 'Booking',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    serviceName ?? 'Service ${booking.serviceId}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (booking.serviceVariant != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${booking.serviceVariant!.name} · '
                      '${booking.serviceVariant!.durationMinutes} min',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    price,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
          if (booking.timeSlots.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Schedule',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...booking.timeSlots.map(
              (slot) => SoftCard(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const HeroIcon(
                    HeroIcons.clock,
                    style: HeroIconStyle.outline,
                  ),
                  title: Text(
                    slot.startTime != null && slot.endTime != null
                        ? '${df.format(slot.startTime!.toLocal())} – '
                          '${df.format(slot.endTime!.toLocal())}'
                        : 'Time slot',
                  ),
                  subtitle: slot.locationType == null
                      ? null
                      : Text(slot.locationType!.title),
                ),
              ),
            ),
          ],
          if (booking.specialRequests != null &&
              booking.specialRequests!.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Special requests',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SoftCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(booking.specialRequests!),
              ),
            ),
          ],
          if (booking.cancellationReason != null &&
              booking.cancellationReason!.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Cancellation',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SoftCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(booking.cancellationReason!),
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (canCancel)
            FilledButton.tonal(
              onPressed: cancelling ? null : onCancel,
              child: cancelling
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Cancel booking'),
            ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.go(AppRoutes.bookings),
            child: const Text('Back to bookings'),
          ),
        ],
      ),
    );
  }
}
