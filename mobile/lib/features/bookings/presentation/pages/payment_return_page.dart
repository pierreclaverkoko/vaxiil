import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/features/bookings/data/bookings_repository.dart';
import 'package:vaxiil_mobile/shared/themes/vaxiil_text.dart';
import 'package:vaxiil_mobile/shared/utils/responsive.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_site_footer.dart';

/// Landing after hosted checkout redirect (`/payment-return?...`).
class PaymentReturnPage extends StatefulWidget {
  const PaymentReturnPage({
    super.key,
    this.reference,
    this.status,
  });

  final String? reference;
  final String? status;

  @override
  State<PaymentReturnPage> createState() => _PaymentReturnPageState();
}

class _PaymentReturnPageState extends State<PaymentReturnPage> {
  var _loading = true;
  String? _message;
  String? _bookingId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Future<void> _resolve() async {
    final ref = widget.reference?.trim() ?? '';
    final status = (widget.status ?? '').toLowerCase();
    if (ref.isEmpty) {
      setState(() {
        _loading = false;
        _message = 'Missing payment reference.';
      });
      return;
    }

    // merchantReference format: bk_<bookingId>_<suffix>
    String? bookingId;
    final parts = ref.split('_');
    if (parts.length >= 3 && parts[0] == 'bk') {
      bookingId = parts[1];
    }

    try {
      if (bookingId != null && bookingId.isNotEmpty) {
        await sl<BookingsRepository>().get(bookingId);
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _bookingId = bookingId;
        if (status == 'completed') {
          _message = 'Payment completed. Your booking is being confirmed.';
        } else if (status == 'failed') {
          _message = 'Payment failed. You can try again from the booking.';
        } else {
          _message = 'Payment status updated. Returning to your booking…';
        }
      });
      if (bookingId != null && bookingId.isNotEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        context.go('${AppRoutes.bookingDetails}?id=$bookingId');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _bookingId = bookingId;
        _message = status == 'completed'
            ? 'Payment completed. Open your bookings to confirm.'
            : 'Could not load booking. Check My Bookings.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final vt = VaxiilText.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      primary: false,
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text('Payment', style: vt.sectionTitle.copyWith(fontSize: 20)),
        backgroundColor: cs.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ResponsiveContent(
              narrowMaxWidth: 672,
              padding: const EdgeInsets.all(24),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Column(
                      children: [
                        Text(
                          _message ?? 'Done',
                          textAlign: TextAlign.center,
                          style: vt.discoverySubtitle,
                        ),
                        const SizedBox(height: 24),
                        if (_bookingId != null && _bookingId!.isNotEmpty)
                          FilledButton(
                            onPressed: () => context.go(
                              '${AppRoutes.bookingDetails}?id=$_bookingId',
                            ),
                            child: const Text('View booking'),
                          )
                        else
                          FilledButton(
                            onPressed: () => context.go(AppRoutes.bookings),
                            child: const Text('My bookings'),
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
}
