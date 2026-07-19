import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:intl/intl.dart';
import 'package:vaxiil_mobile/shared/utils/platform_fee_utils.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/features/bookings/data/booking_models.dart';
import 'package:vaxiil_mobile/features/bookings/data/bookings_repository.dart';
import 'package:vaxiil_mobile/features/bookings/presentation/widgets/booking_price_breakdown.dart';
import 'package:vaxiil_mobile/features/services/data/service_catalog_repository.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/widgets/soft_card.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_site_footer.dart';

/// Shown after a successful booking request (`?id=` booking id).
class BookingConfirmationPage extends StatefulWidget {
  const BookingConfirmationPage({required this.bookingId, super.key});

  final String bookingId;

  @override
  State<BookingConfirmationPage> createState() =>
      _BookingConfirmationPageState();
}

class _BookingConfirmationPageState extends State<BookingConfirmationPage> {
  BookingDetailModel? _booking;
  String? _serviceName;
  Object? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.bookingId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Missing booking reference';
      });
      return;
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirmation')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ResponsiveContent(
                    narrowMaxWidth: 672,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                  const HeroIcon(
                    HeroIcons.checkCircle,
                    style: HeroIconStyle.solid,
                    size: 72,
                    color: AppTheme.successColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Booking requested',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We have received your request. You will see updates in '
                    'your bookings list.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      _err(_error!),
                      style: const TextStyle(color: AppTheme.errorColor),
                    ),
                  ],
                  if (_booking != null) ...[
                    const SizedBox(height: 24),
                    SoftCard(
                      padding: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _serviceName ?? 'Service',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _booking!.status?.title ?? 'Requested',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            if (_booking!.timeSlots.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                _formatSlot(_booking!.timeSlots.first),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppTheme.textSecondary),
                              ),
                            ],
                            const SizedBox(height: 12),
                            if (_booking != null)
                              BookingPriceBreakdown.fromComputed(
                                currencyCode: _booking!.currencyCode ?? 'USD',
                                computed: _priceBreakdown(_booking!),
                                feePayerTitle:
                                    _booking!.platformFeePayer?.title,
                                compact: true,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: () => context.go(
                      '${AppRoutes.bookingDetails}?id=${widget.bookingId}',
                    ),
                    child: const Text('View booking'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => context.go(AppRoutes.bookings),
                    child: const Text('Back to bookings'),
                  ),
                      ],
                    ),
                  ),
                  const VaxiilSiteFooter(),
                ],
              ),
            ),
    );
  }

  String _formatSlot(BookingTimeSlotModel slot) {
    final df = DateFormat.yMMMd().add_jm();
    if (slot.startTime != null && slot.endTime != null) {
      return '${df.format(slot.startTime!.toLocal())} – '
          '${df.format(slot.endTime!.toLocal())}';
    }
    return '';
  }

  ComputedBookingPrice _priceBreakdown(BookingDetailModel b) {
    final total = double.tryParse(b.totalPrice) ?? 0;
    final base = double.tryParse(b.basePrice ?? b.totalPrice) ?? total;
    final fee = double.tryParse(b.platformFeeAmount ?? '0') ?? 0;
    final rate = double.tryParse(b.platformFeeRate ?? '') ?? 0;
    return ComputedBookingPrice(
      basePrice: base,
      feeRate: rate,
      feeAmount: fee,
      totalPrice: total,
      clientPaysFee: b.showsClientFeeBreakdown,
    );
  }
}
