import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/core/utils/hero_icon_from_name.dart';
import 'package:vaxiil_mobile/features/bookings/data/booking_models.dart';
import 'package:vaxiil_mobile/features/bookings/data/bookings_repository.dart';
import 'package:vaxiil_mobile/features/bookings/presentation/utils/booking_schedule_utils.dart';
import 'package:vaxiil_mobile/features/bookings/presentation/widgets/booking_category_meta.dart';
import 'package:vaxiil_mobile/features/bookings/presentation/widgets/booking_open_slots_sheet.dart';
import 'package:vaxiil_mobile/features/bookings/presentation/widgets/booking_price_breakdown.dart';
import 'package:vaxiil_mobile/features/services/data/service_catalog_models.dart';
import 'package:vaxiil_mobile/features/services/data/service_catalog_repository.dart';
import 'package:vaxiil_mobile/l10n/app_localizations.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/themes/vaxiil_text.dart';
import 'package:vaxiil_mobile/shared/utils/responsive.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_site_footer.dart';

/// Booking detail: Stitch **Past** (“Session History”) vs **Upcoming** layouts.
class BookingDetailPage extends StatefulWidget {
  const BookingDetailPage({required this.bookingId, super.key});

  final String bookingId;

  @override
  State<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage>
    with WidgetsBindingObserver {
  BookingDetailModel? _booking;
  ServiceDetailModel? _service;
  Object? _error;
  var _loading = true;
  var _cancelling = false;
  var _paying = false;
  var _rescheduleBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_loading && !_paying) {
      _load();
    }
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
      ServiceDetailModel? svc;
      if (b.serviceId.isNotEmpty) {
        try {
          svc = await sl<ServiceCatalogRepository>().getService(b.serviceId);
        } catch (_) {
          svc = null;
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _booking = b;
        _service = svc;
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
      final out = await sl<BookingsRepository>().cancel(widget.bookingId);
      if (!mounted) {
        return;
      }
      var msg = 'Booking cancelled';
      final refund = out['refund'];
      if (refund is Map) {
        final attempted = refund['attempted'];
        final amt = refund['amount'];
        final cur = refund['currency_code'];
        if (attempted == true && amt != null) {
          final dest = refund['destination']?.toString();
          msg = dest == 'wallet'
              ? AppLocalizations.of(context).bookingCancelledEscrowCredit(
                  '$amt',
                  '${cur ?? ''}'.trim(),
                )
              : 'Booking cancelled. Refund: $amt ${cur ?? ''}'.trim();
        } else if (refund['reason'] == 'policy_zero_refund') {
          msg = 'Booking cancelled (no refund per policy).';
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
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

  void _openServiceBooking(BookingDetailModel b) {
    if (b.serviceId.isEmpty) return;
    final v = b.serviceVariant?.id;
    final q = v != null && v.isNotEmpty ? '&variantId=$v' : '';
    context.push('${AppRoutes.serviceBooking}?id=${b.serviceId}$q');
  }

  Future<void> _proposeReschedule() async {
    final b = _booking;
    if (b == null || _rescheduleBusy || widget.bookingId.isEmpty) return;
    if (b.serviceId.isEmpty) return;
    final slot = b.timeSlots.isNotEmpty ? b.timeSlots.first : null;
    final durationMinutes = bookingDurationMinutes(b);
    final advanceDays = _service?.bookingAdvanceDays;
    final pick = await showBookingOpenSlotsSheet(
      context: context,
      serviceId: b.serviceId,
      durationMinutes: durationMinutes,
      excludeBookingId: widget.bookingId,
      initialDate: slot?.startTime?.toLocal(),
      advanceDays: (advanceDays != null && advanceDays > 0) ? advanceDays : 365,
    );
    if (pick == null || !mounted) return;
    final locationCode = slot?.locationType?.value ?? 'O';
    setState(() => _rescheduleBusy = true);
    try {
      await sl<BookingsRepository>().reschedule(widget.bookingId, [
        {
          'start_time': pick.startTime.toUtc().toIso8601String(),
          'end_time': pick.endTime.toUtc().toIso8601String(),
          'location_type': locationCode,
        },
      ]);
      if (!mounted) return;
      _snack(AppLocalizations.of(context).bookingRescheduleProposed);
      await _load();
    } catch (e) {
      if (mounted) _snack(_err(e));
    } finally {
      if (mounted) setState(() => _rescheduleBusy = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool get _canRespondToBusinessReschedule {
    final b = _booking;
    if (b == null) return false;
    return b.status?.value == 'R' &&
        b.pendingReschedule != null &&
        b.pendingReschedule!.isProposedByBusiness;
  }

  bool get _canAcceptReschedule {
    final b = _booking;
    return _canRespondToBusinessReschedule && (b?.isPaid ?? false);
  }

  bool get _showPayCta {
    final b = _booking;
    if (b == null || b.isPaid) return false;
    if (b.status?.value == 'R' && b.pendingReschedule != null) return true;
    final status = b.status?.value;
    return status == 'Q' || status == 'D';
  }

  Future<void> _acceptReschedule() async {
    if (_rescheduleBusy || widget.bookingId.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _rescheduleBusy = true);
    try {
      final booking =
          await sl<BookingsRepository>().acceptReschedule(widget.bookingId);
      if (!mounted) return;
      setState(() => _booking = booking);
      _snack(l10n.bookingRescheduleAccepted);
    } catch (e) {
      if (mounted) _snack(_err(e));
    } finally {
      if (mounted) setState(() => _rescheduleBusy = false);
    }
  }

  Future<void> _declineReschedule() async {
    if (_rescheduleBusy || widget.bookingId.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _rescheduleBusy = true);
    try {
      final booking =
          await sl<BookingsRepository>().declineReschedule(widget.bookingId);
      if (!mounted) return;
      setState(() => _booking = booking);
      _snack(l10n.bookingRescheduleDeclined);
    } catch (e) {
      if (mounted) _snack(_err(e));
    } finally {
      if (mounted) setState(() => _rescheduleBusy = false);
    }
  }

  Future<void> _payNow() async {
    if (_paying || widget.bookingId.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    var applyWallet = false;
    String? escrowCurrency;
    try {
      final wallet = await sl<BookingsRepository>().getWallet();
      final code = (_booking?.currencyCode ?? '').toUpperCase();
      final match = wallet.balances.where(
        (row) =>
            row.currencyCode.toUpperCase() == code &&
            (double.tryParse(row.balance) ?? 0) > 0,
      );
      if (match.isNotEmpty && mounted) {
        final bal = match.first;
        escrowCurrency = bal.currencyCode;
        final total = double.tryParse(_booking?.totalPrice ?? '') ?? 0;
        final available = double.tryParse(bal.balance) ?? 0;
        final applied = total > 0 && available > 0
            ? (total < available ? total : available)
            : 0.0;
        final cardRemaining =
            total > applied ? (total - applied) : 0.0;
        final use = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.payUseEscrowTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.payUseEscrowBody(bal.balance, bal.currencyCode),
                ),
                if (applied > 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${l10n.payEscrowApplied}: '
                    '${applied.toStringAsFixed(2)} ${bal.currencyCode}',
                  ),
                  Text(
                    '${l10n.payCardAmount}: '
                    '${cardRemaining.toStringAsFixed(2)} ${bal.currencyCode}',
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.payUseEscrowNo),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l10n.payUseEscrowYes),
              ),
            ],
          ),
        );
        applyWallet = use == true;
      }
    } catch (_) {
      // Wallet optional; continue to payment link.
    }
    if (!mounted) return;
    setState(() => _paying = true);
    try {
      final link = await sl<BookingsRepository>().createPaymentLink(
        widget.bookingId,
        applyWallet: applyWallet,
      );
      if (!mounted) return;
      if (link.fullyPaid) {
        _snack(l10n.payFullyPaidEscrow);
        await _load();
        return;
      }
      if (applyWallet &&
          (double.tryParse(link.walletApplied) ?? 0) > 0 &&
          mounted) {
        final code = escrowCurrency ?? _booking?.currencyCode ?? '';
        _snack(
          '${l10n.payEscrowApplied}: ${link.walletApplied} $code · '
          '${l10n.payCardAmount}: ${link.amountCharged} $code',
        );
      }
      final url = link.url ?? '';
      if (url.isEmpty) {
        _snack('Payment link was empty. Try again.');
        return;
      }
      final uri = Uri.parse(url);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        _snack('Could not open the payment page.');
      }
    } catch (e) {
      if (mounted) {
        _snack(_err(e));
      }
    } finally {
      if (mounted) {
        setState(() => _paying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _booking;
    final past = b?.isPastBooking ?? false;
    final cs = Theme.of(context).colorScheme;
    final vt = VaxiilText.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark,
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: cs.surface,
      ),
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppTheme.backgroundColor.withOpacity(0.92),
          elevation: 0,
          title: Text(
            past ? 'Session History' : 'Booking Details',
            style: vt.sectionTitle.copyWith(fontSize: 22),
          ),
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
                : b == null
                    ? const SizedBox.shrink()
                    : past
                        ? _PastBookingBody(
                            booking: b,
                            service: _service,
                            onRebook: () => _openServiceBooking(b),
                            onReportIssue: () => _snack(
                              'Thanks — support will follow up if needed.',
                            ),
                            onSecurityIssue: () => _snack(
                              'Please contact support from your profile.',
                            ),
                            onRateTap: () => _snack(
                              'Reviews will be available in a future update.',
                            ),
                          )
                        : _UpcomingBookingBody(
                            booking: b,
                            service: _service,
                            canCancel: _canCancel,
                            cancelling: _cancelling,
                            onCancel: _confirmCancel,
                            onReschedule: _proposeReschedule,
                            onPayNow: _paying ? () {} : _payNow,
                            showPayCta: _showPayCta,
                            showRescheduleDecision:
                                _canRespondToBusinessReschedule,
                            canAcceptReschedule: _canAcceptReschedule,
                            rescheduleBusy: _rescheduleBusy,
                            onAcceptReschedule: _acceptReschedule,
                            onDeclineReschedule: _declineReschedule,
                          ),
      ),
    );
  }
}

// --- Past (Session History) ---

class _PastBookingBody extends StatelessWidget {
  const _PastBookingBody({
    required this.booking,
    required this.service,
    required this.onRebook,
    required this.onReportIssue,
    required this.onSecurityIssue,
    required this.onRateTap,
  });

  final BookingDetailModel booking;
  final ServiceDetailModel? service;
  final VoidCallback onRebook;
  final VoidCallback onReportIssue;
  final VoidCallback onSecurityIssue;
  final VoidCallback onRateTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vt = VaxiilText.of(context);
    final title = booking.displayServiceTitle(service?.name);
    final heroUrl = service?.primaryImage;
    final currency = booking.currencyCode ?? 'USD';
    final variant = booking.serviceVariant;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: context.isExpandedShell ? 32 : 120,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ResponsiveContent(
            narrowMaxWidth: 672,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          Center(
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 18,
                        color: cs.onSecondaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        booking.status?.title ?? 'Completed',
                        style: vt.categoryLabel.copyWith(
                          color: cs.onSecondaryContainer,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: vt.greeting.copyWith(
                    fontSize: 28,
                    color: cs.onSurface,
                  ),
                ),
                BookingCategoryMeta(
                  category: booking.resolvedCategory(service),
                  centered: true,
                ),
                const SizedBox(height: 8),
                Text(
                  _sessionWhenLine(booking),
                  textAlign: TextAlign.center,
                  style: vt.discoverySubtitle,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ColoredBox(
              color: cs.surfaceContainerLow,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: heroUrl != null && heroUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: heroUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: cs.surfaceContainerHighest,
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: cs.surfaceContainerHighest,
                              child:
                                  Icon(Icons.spa_outlined, color: cs.primary),
                            ),
                          )
                        : Container(
                            color: cs.surfaceContainerHighest,
                            alignment: Alignment.center,
                            child: Icon(Icons.spa_outlined,
                                color: cs.primary, size: 48),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(22),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Service Provider',
                                style: vt.sectionTitle.copyWith(fontSize: 18),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                booking.practitionerDisplayLine ??
                                    'Your provider',
                                style: vt.discoverySubtitle,
                              ),
                            ],
                          ),
                        ),
                        _CircleAvatarUrl(
                          url: booking.practitioner?.avatarUrl ??
                              booking.organizationLogoUrl,
                          fallback: Icons.person_outline,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          BookingPaymentSummaryPanel.fromBooking(
            currencyCode: currency,
            totalPrice: booking.totalPrice,
            basePrice: booking.basePrice,
            platformFeeAmount: booking.platformFeeAmount,
            platformFeeRate: booking.platformFeeRate,
            platformFeePayerValue: booking.platformFeePayer?.value,
            variantName: variant?.name,
            variantPrice: variant?.price,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  'Rate your experience',
                  style: vt.sectionTitle.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    5,
                    (i) => IconButton(
                      onPressed: onRateTap,
                      icon: Icon(
                        Icons.star_rounded,
                        size: 36,
                        color: i < 4
                            ? const Color(0xFFF59E0B)
                            : cs.surfaceContainerHighest,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap a star to leave feedback when reviews go live.',
                  textAlign: TextAlign.center,
                  style: vt.discoverySubtitle.copyWith(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onReportIssue,
            icon: Icon(Icons.report_outlined, color: cs.error),
            label: Text(
              'Report a problem',
              style: TextStyle(
                color: cs.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onSecurityIssue,
            icon: const Icon(
              Icons.security_outlined,
              color: Color(0xFFF59E0B),
            ),
            label: const Text(
              'Security issue',
              style: TextStyle(
                color: Color(0xFFF59E0B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRebook,
            style: FilledButton.styleFrom(
              backgroundColor: cs.primaryContainer,
              foregroundColor: cs.onPrimaryContainer,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.event_repeat),
                const SizedBox(width: 10),
                Text(
                  'Rebook session',
                  style: vt.cardTitle.copyWith(color: cs.onPrimaryContainer),
                ),
              ],
            ),
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
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.label,
    required this.value,
    required this.vt,
    required this.cs,
  });

  final String label;
  final String value;
  final VaxiilText vt;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: vt.discoverySubtitle,
          ),
        ),
        Text(
          value,
          style: vt.categoryLabel.copyWith(color: cs.onSurface),
        ),
      ],
    );
  }
}

// --- Upcoming ---

class _UpcomingBookingBody extends StatelessWidget {
  const _UpcomingBookingBody({
    required this.booking,
    required this.service,
    required this.canCancel,
    required this.cancelling,
    required this.onCancel,
    required this.onReschedule,
    required this.onPayNow,
    required this.showPayCta,
    required this.showRescheduleDecision,
    required this.canAcceptReschedule,
    required this.rescheduleBusy,
    required this.onAcceptReschedule,
    required this.onDeclineReschedule,
  });

  final BookingDetailModel booking;
  final ServiceDetailModel? service;
  final bool canCancel;
  final bool cancelling;
  final VoidCallback onCancel;
  final VoidCallback onReschedule;
  final VoidCallback onPayNow;
  final bool showPayCta;
  final bool showRescheduleDecision;
  final bool canAcceptReschedule;
  final bool rescheduleBusy;
  final VoidCallback onAcceptReschedule;
  final VoidCallback onDeclineReschedule;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vt = VaxiilText.of(context);
    final title = booking.displayServiceTitle(service?.name);
    final orgName =
        booking.organizationName ?? service?.organization.name ?? '';
    final heroUrl = service?.primaryImage;
    final slot = booking.timeSlots.isNotEmpty ? booking.timeSlots.first : null;
    final start = slot?.startTime;
    final end = slot?.endTime;
    final dateStr =
        start != null ? DateFormat.yMMMd().format(start.toLocal()) : '—';
    final timeStr =
        start != null ? DateFormat.jm().format(start.toLocal()) : '—';
    final rating = service?.averageRating;
    final reviews = service?.ratingCount;
    final cat = booking.resolvedCategory(service);
    final catIcon = heroIconFromDbName(
      cat != null && cat.icon.isNotEmpty ? cat.icon : null,
      fallback: HeroIcons.sparkles,
    );

    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: context.isExpandedShell ? 120 : 140,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ResponsiveContent(
                narrowMaxWidth: 672,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
              _UpcomingStatusBanner(booking: booking, vt: vt, cs: cs),
              if (showRescheduleDecision) ...[
                const SizedBox(height: 12),
                Material(
                  color: cs.primaryContainer.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      canAcceptReschedule
                          ? AppLocalizations.of(context)
                              .bookingReschedulePendingBusiness
                          : AppLocalizations.of(context)
                              .bookingReschedulePayFirst,
                      style: vt.discoverySubtitle.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (canAcceptReschedule) ...[
                      Expanded(
                        child: FilledButton(
                          onPressed:
                              rescheduleBusy ? null : onAcceptReschedule,
                          child: Text(
                            AppLocalizations.of(context)
                                .bookingAcceptReschedule,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            rescheduleBusy ? null : onDeclineReschedule,
                        child: Text(
                          AppLocalizations.of(context)
                              .bookingDeclineReschedule,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    right: 0,
                    top: -16,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.primaryContainer.withOpacity(0.12),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppTheme.editorialShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: vt.greeting.copyWith(
                                      fontSize: 28,
                                      color: cs.primary,
                                    ),
                                  ),
                                  BookingCategoryMeta(
                                    category: cat,
                                  ),
                                  if (orgName.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      orgName,
                                      style: vt.discoverySubtitle.copyWith(
                                        color: cs.secondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cs.primaryFixed,
                                shape: BoxShape.circle,
                              ),
                              child: HeroIcon(
                                catIcon,
                                style: HeroIconStyle.outline,
                                color: cs.onPrimaryFixedVariant,
                                size: 28,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: 192,
                            width: double.infinity,
                            child: heroUrl != null && heroUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: heroUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(
                                      color: cs.surfaceContainerHighest,
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      color: cs.surfaceContainerHighest,
                                      child: Icon(
                                        Icons.forest_outlined,
                                        color: cs.primary,
                                        size: 56,
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: cs.surfaceContainerHighest,
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.forest_outlined,
                                      color: cs.primary,
                                      size: 56,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _DateTimeTile(
                                icon: Icons.calendar_today_outlined,
                                label: 'Date',
                                value: dateStr,
                                vt: vt,
                                cs: cs,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _DateTimeTile(
                                icon: Icons.schedule,
                                label: 'Time',
                                value: end != null && start != null
                                    ? '${DateFormat.jm().format(start.toLocal())} – '
                                        '${DateFormat.jm().format(end.toLocal())}'
                                    : timeStr,
                                vt: vt,
                                cs: cs,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: cs.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _CircleAvatarUrl(
                          url: booking.practitioner?.avatarUrl,
                          size: 80,
                          fallback: Icons.person,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: cs.primaryFixed,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: cs.surfaceContainer,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.verified,
                              size: 14,
                              color: cs.onPrimaryFixedVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Practitioner',
                            style: vt.categoryLabel.copyWith(
                              color: cs.secondary,
                              letterSpacing: 1.5,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            booking.practitionerDisplayLine ??
                                'Provider assigned',
                            style: vt.cardTitle.copyWith(fontSize: 20),
                          ),
                          if (orgName.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              orgName,
                              style:
                                  vt.discoverySubtitle.copyWith(fontSize: 13),
                            ),
                          ],
                          if (rating != null && reviews != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.star, size: 18, color: cs.primary),
                                const SizedBox(width: 4),
                                Text(
                                  '${rating.toStringAsFixed(1)} ($reviews reviews)',
                                  style: vt.categoryLabel.copyWith(
                                    color: cs.primary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!showRescheduleDecision) ...[
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: rescheduleBusy ? null : onReschedule,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.onSurfaceVariant,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: cs.outline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: Text(
                    'Reschedule',
                    style: vt.cardTitle.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (canCancel)
                TextButton(
                  onPressed: cancelling ? null : onCancel,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFEA580C),
                  ),
                  child: cancelling
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Cancel booking',
                          style: vt.cardTitle.copyWith(
                            color: const Color(0xFFEA580C),
                          ),
                        ),
                ),
              const SizedBox(height: 8),
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
        if (showPayCta)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    AppTheme.backgroundColor,
                    AppTheme.backgroundColor.withOpacity(0),
                  ],
                ),
              ),
              child: SafeArea(
                top: false,
                child: ResponsiveContent(
                  narrowMaxWidth: 672,
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: FilledButton(
                    onPressed: onPayNow,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.ctaFill,
                      foregroundColor: AppTheme.onCtaFill,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      elevation: 8,
                      shadowColor: cs.primary.withOpacity(0.2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.payments_outlined),
                        const SizedBox(width: 10),
                        Text(
                          'Pay now',
                          style: vt.greeting.copyWith(
                            fontSize: 18,
                            color: AppTheme.onCtaFill,
                          ),
                        ),
                      ],
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

class _UpcomingStatusBanner extends StatelessWidget {
  const _UpcomingStatusBanner({
    required this.booking,
    required this.vt,
    required this.cs,
  });

  final BookingDetailModel booking;
  final VaxiilText vt;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final v = booking.status?.value ?? '';
    late final Color bg;
    late final Color iconBg;
    late final Color fg;
    late final IconData icon;
    late final String headline;
    late final String detail;

    switch (v) {
      case 'Q':
      case 'D':
        bg = Colors.orange.shade50;
        iconBg = Colors.orange.shade100;
        fg = Colors.orange.shade900;
        icon = Icons.pending_outlined;
        headline = 'Status';
        detail = 'Waiting for provider confirmation';
      case 'F':
      case 'P':
        bg = cs.secondaryContainer.withOpacity(0.5);
        iconBg = cs.secondaryContainer;
        fg = cs.onSecondaryContainer;
        icon = Icons.check_circle_outline;
        headline = 'Status';
        detail =
            v == 'P' ? 'Session in progress' : 'Confirmed — you are all set';
      case 'R':
        bg = cs.primaryContainer.withOpacity(0.2);
        iconBg = cs.primaryContainer.withOpacity(0.4);
        fg = cs.onSurface;
        icon = Icons.event_repeat;
        headline = 'Status';
        detail = booking.status?.title ?? 'Rescheduled';
      default:
        bg = cs.surfaceContainerHigh;
        iconBg = cs.surfaceContainerHighest;
        fg = cs.onSurface;
        icon = Icons.info_outline;
        headline = 'Status';
        detail = booking.status?.title ?? 'Booking';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: v == 'Q' || v == 'D' ? Colors.orange.shade800 : fg,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline.toUpperCase(),
                  style: vt.categoryLabel.copyWith(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: v == 'Q' || v == 'D' ? Colors.orange.shade900 : fg,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: vt.cardTitle.copyWith(
                    fontSize: 15,
                    color: v == 'Q' || v == 'D' ? Colors.orange.shade900 : fg,
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

class _DateTimeTile extends StatelessWidget {
  const _DateTimeTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.vt,
    required this.cs,
  });

  final IconData icon;
  final String label;
  final String value;
  final VaxiilText vt;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: cs.primary),
          const SizedBox(height: 8),
          Text(
            label.toUpperCase(),
            style: vt.categoryLabel.copyWith(
              fontSize: 10,
              letterSpacing: 1.5,
              color: cs.outline,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: vt.cardTitle.copyWith(fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _CircleAvatarUrl extends StatelessWidget {
  const _CircleAvatarUrl({
    required this.url,
    required this.fallback,
    this.size = 56,
  });

  final String? url;
  final IconData fallback;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (url != null && url!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            width: size,
            height: size,
            color: cs.surfaceContainerHighest,
          ),
          errorWidget: (_, __, ___) => _fallbackIcon(cs),
        ),
      );
    }
    return _fallbackIcon(cs);
  }

  Widget _fallbackIcon(ColorScheme cs) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Icon(fallback, color: cs.primary),
    );
  }
}

String _sessionWhenLine(BookingDetailModel b) {
  if (b.timeSlots.isEmpty) {
    return 'Schedule details unavailable';
  }
  final s = b.timeSlots.first;
  final st = s.startTime;
  final en = s.endTime;
  if (st == null) return 'Schedule details unavailable';
  final day = DateFormat('EEEE, MMM d').format(st.toLocal());
  final t1 = DateFormat.jm().format(st.toLocal());
  if (en != null) {
    final t2 = DateFormat.jm().format(en.toLocal());
    return '$day • $t1 - $t2';
  }
  return '$day • $t1';
}
