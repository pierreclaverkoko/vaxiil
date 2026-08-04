import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vaxiil_mobile/core/constants/app_constants.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/features/bookings/data/booking_models.dart';
import 'package:vaxiil_mobile/features/bookings/data/bookings_repository.dart';
import 'package:vaxiil_mobile/features/bookings/presentation/utils/booking_schedule_utils.dart';
import 'package:vaxiil_mobile/features/bookings/presentation/widgets/booking_open_slots_sheet.dart';
import 'package:vaxiil_mobile/features/messages/data/messaging_repository.dart';
import 'package:vaxiil_mobile/l10n/app_localizations.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/utils/responsive.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_site_footer.dart';

/// Organization staff: customer, payment summary, cancel / reschedule.
class BusinessBookingDetailPage extends StatefulWidget {
  const BusinessBookingDetailPage({
    required this.bookingId,
    required this.organizationId,
    super.key,
  });

  final String bookingId;
  final String organizationId;

  @override
  State<BusinessBookingDetailPage> createState() =>
      _BusinessBookingDetailPageState();
}

class _BusinessBookingDetailPageState extends State<BusinessBookingDetailPage> {
  BookingDetailModel? _booking;
  Object? _error;
  var _loading = true;
  var _busy = false;

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
      if (!mounted) return;
      setState(() {
        _booking = b;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  String _err(Object e) => e is Failure ? e.message : e.toString();

  bool get _isTerminal {
    final s = _booking?.status?.value;
    if (s == null) return true;
    return {'M', 'X', 'N'}.contains(s);
  }

  bool get _canCancel {
    final s = _booking?.status?.value;
    return s == 'F' || s == 'P';
  }

  bool get _showBottomActions {
    final b = _booking;
    if (b == null || _isTerminal) return false;
    if (AppConstants.messagesEnabled && b.canMessageBooking()) return true;
    final s = b.status?.value;
    if (s == 'Q' || s == 'F' || s == 'P') return true;
    if (s == 'R' &&
        b.pendingReschedule != null &&
        b.pendingReschedule!.isProposedByClient) {
      return true;
    }
    if (s == 'R' &&
        (b.pendingReschedule == null ||
            !b.pendingReschedule!.isProposedByBusiness)) {
      return true;
    }
    return _canCancel;
  }

  Future<void> _openMessage() async {
    final b = _booking;
    if (b == null || _busy || !b.canMessageBooking()) return;
    setState(() => _busy = true);
    try {
      final conversation =
          await sl<MessagingRepository>().openBookingThread(b.id);
      if (!mounted) return;
      context.push(
        '${AppRoutes.messages}/${conversation.id}'
        '?organizationId=${widget.organizationId}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_err(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runStaffAction(
    String successMessage,
    Future<BookingDetailModel> Function(BookingsRepository repo) action,
  ) async {
    setState(() => _busy = true);
    try {
      final booking = await action(sl<BookingsRepository>());
      if (!mounted) return;
      setState(() => _booking = booking);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_err(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _promptReason({
    required String title,
    required String hint,
  }) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null) {
      return null;
    }
    if (reason.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A reason is required.')),
        );
      }
      return null;
    }
    return reason;
  }

  Future<void> _confirmReject() async {
    final reason = await _promptReason(
      title: 'Reject booking',
      hint: 'Tell the client why this booking cannot be accepted',
    );
    if (reason == null || !mounted) {
      return;
    }
    await _runStaffAction(
      'Booking rejected',
      (repo) => repo.reject(widget.bookingId, reason: reason),
    );
  }

  Future<void> _confirmCancel() async {
    final reason = await _promptReason(
      title: 'Cancel booking',
      hint: 'Reason for cancelling this booking',
    );
    if (reason == null || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      final out = await sl<BookingsRepository>().cancel(
        widget.bookingId,
        reason: reason,
      );
      if (!mounted) return;
      final refund = out['refund'];
      var msg = 'Booking cancelled';
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_err(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _acceptReschedule() async {
    final l10n = AppLocalizations.of(context);
    await _runStaffAction(
      l10n.bookingRescheduleAccepted,
      (repo) => repo.acceptReschedule(widget.bookingId),
    );
  }

  Future<void> _declineReschedule() async {
    final l10n = AppLocalizations.of(context);
    await _runStaffAction(
      l10n.bookingRescheduleDeclined,
      (repo) => repo.declineReschedule(widget.bookingId),
    );
  }

  Future<void> _reschedule() async {
    final b = _booking;
    if (b == null) return;
    if (b.serviceId.isEmpty) return;
    final slot = b.timeSlots.isNotEmpty ? b.timeSlots.first : null;
    final pick = await showBookingOpenSlotsSheet(
      context: context,
      serviceId: b.serviceId,
      durationMinutes: bookingDurationMinutes(b),
      excludeBookingId: widget.bookingId,
      initialDate: slot?.startTime?.toLocal(),
    );
    if (pick == null || !mounted) return;
    final locationCode = slot?.locationType?.value ?? 'O';
    setState(() => _busy = true);
    try {
      await sl<BookingsRepository>().reschedule(widget.bookingId, [
        {
          'start_time': pick.startTime.toUtc().toIso8601String(),
          'end_time': pick.endTime.toUtc().toIso8601String(),
          'location_type': locationCode,
        },
      ]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).bookingRescheduleProposed),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_err(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final b = _booking;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Booking'),
        actions: [
          IconButton(
            onPressed: _loading || _busy ? null : _load,
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
                  : Stack(
                      children: [
                        ListView(
                          padding: EdgeInsets.only(
                            bottom: context.isExpandedShell ? 120 : 140,
                          ),
                          children: [
                            ResponsiveContent(
                              narrowMaxWidth: 672,
                              padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    b.displayServiceTitle(null),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text(
                                        b.status?.title ?? '',
                                        style: TextStyle(
                                          color: cs.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (b.status?.value == 'Q' &&
                                          b.isPaid) ...[
                                        const SizedBox(width: 10),
                                        Chip(
                                          avatar: Icon(
                                            Icons.payments_outlined,
                                            size: 16,
                                            color: cs.onSecondaryContainer,
                                          ),
                                          label: Text(
                                            AppLocalizations.of(context)
                                                .bookingPaidBadge,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          backgroundColor:
                                              cs.secondaryContainer,
                                          labelStyle: TextStyle(
                                            color: cs.onSecondaryContainer,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (b.status?.value == 'R' &&
                                      b.pendingReschedule != null &&
                                      b.pendingReschedule!
                                          .isProposedByBusiness) ...[
                                    const SizedBox(height: 12),
                                    Material(
                                      color: cs.primaryContainer
                                          .withOpacity(0.35),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.hourglass_top_outlined,
                                              color: cs.primary,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                AppLocalizations.of(context)
                                                    .bookingReschedulePendingClient,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 24),
                                  Text(
                                    'Customer',
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 8),
                                  if (b.client != null)
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(Icons.person_outline),
                                      title: Text(b.client!.displayName),
                                      subtitle: _clientDetails(b.client!),
                                    )
                                  else
                                    const Text('—'),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Payment',
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 8),
                                  ..._paymentRows(context, b),
                                  if ((b.cancellationReason ?? '')
                                      .trim()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    Text(
                                      'Cancellation reason',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(b.cancellationReason!),
                                  ],
                                  if ((b.internalNotes ?? '')
                                      .trim()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    Text(
                                      'Internal notes',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(b.internalNotes!),
                                  ],
                                  if ((b.specialRequests ?? '')
                                      .trim()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    Text(
                                      AppLocalizations.of(context)
                                          .businessBookingSpecialRequests,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(b.specialRequests!),
                                  ],
                                  const SizedBox(height: 16),
                                  Text(
                                    'Session',
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 8),
                                  ...b.timeSlots.map(
                                    (s) => Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s.startTime != null
                                                ? '${DateFormat.yMMMd().format(s.startTime!.toLocal())} '
                                                    '${DateFormat.jm().format(s.startTime!.toLocal())} — '
                                                    '${s.endTime != null ? DateFormat.jm().format(s.endTime!.toLocal()) : '—'}'
                                                : '—',
                                          ),
                                          if (_slotVenueLines(s).isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              AppLocalizations.of(context)
                                                  .businessBookingVenue,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelLarge
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            ..._slotVenueWidgets(context, s),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const VaxiilSiteFooter(),
                          ],
                        ),
                        if (_busy)
                          const Positioned.fill(
                            child: IgnorePointer(
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          ),
                      ],
                    ),
      bottomNavigationBar: b == null || !_showBottomActions
          ? null
          : SafeArea(
              child: ResponsiveContent(
                narrowMaxWidth: 672,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: _buildBottomActions(context, b, cs),
              ),
            ),
    );
  }

  Widget _buildBottomActions(
    BuildContext context,
    BookingDetailModel b,
    ColorScheme cs,
  ) {
    final l10n = AppLocalizations.of(context);
    final status = b.status?.value;
    final pending = b.pendingReschedule;

    if (status == 'Q') {
      final canMessage =
          AppConstants.messagesEnabled && b.canMessageBooking() && !_busy;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!b.isPaid)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.bookingCannotAcceptUnpaid,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ),
          if (canMessage) ...[
            OutlinedButton(
              onPressed: _openMessage,
              child: Text(l10n.businessBookingMessage),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _busy || !b.isPaid
                      ? null
                      : () => _runStaffAction(
                            'Booking accepted',
                            (repo) => repo.confirm(widget.bookingId),
                          ),
                  child: const Text('Accept'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _confirmReject,
                  child: const Text('Reject'),
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (status == 'R' &&
        pending != null &&
        pending.isProposedByClient) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!b.isPaid)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.bookingCannotAcceptUnpaid,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _busy || !b.isPaid ? null : _acceptReschedule,
                  child: Text(l10n.bookingAcceptReschedule),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _declineReschedule,
                  child: Text(l10n.bookingDeclineReschedule),
                ),
              ),
            ],
          ),
        ],
      );
    }

    final canComplete = status == 'F' && !_busy && _sessionHasStarted(b);
    final canMessage =
        AppConstants.messagesEnabled && b.canMessageBooking() && !_busy;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (status == 'F' && !_sessionHasStarted(b))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.businessBookingCompleteBeforeStart,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ),
        if (canMessage) ...[
          OutlinedButton(
            onPressed: _openMessage,
            child: Text(l10n.businessBookingMessage),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            if (status == 'F') ...[
              Expanded(
                child: FilledButton(
                  onPressed: !canComplete
                      ? null
                      : () => _runStaffAction(
                            l10n.businessBookingCompletedSnackbar,
                            (repo) => repo.complete(widget.bookingId),
                          ),
                  child: Text(l10n.businessBookingComplete),
                ),
              ),
              const SizedBox(width: 12),
            ],
            if (pending == null || !pending.isProposedByBusiness) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _reschedule,
                  child: const Text('Reschedule'),
                ),
              ),
            ],
            if (_canCancel) ...[
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _confirmCancel,
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.error,
                    foregroundColor: cs.onError,
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  bool _sessionHasStarted(BookingDetailModel b) {
    final start = b.earliestSlotStart;
    if (start == null) {
      return false;
    }
    final now = DateTime.now();
    return !start.isAfter(now);
  }

  List<String> _slotVenueLines(BookingTimeSlotModel s) {
    return [
      if ((s.locationType?.title ?? '').trim().isNotEmpty) s.locationType!.title,
      if ((s.address ?? '').trim().isNotEmpty) s.address!.trim(),
      if ((s.roomDetails ?? '').trim().isNotEmpty) s.roomDetails!.trim(),
      if ((s.virtualMeetingLink ?? '').trim().isNotEmpty)
        s.virtualMeetingLink!.trim(),
      if ((s.notes ?? '').trim().isNotEmpty) s.notes!.trim(),
    ];
  }

  List<Widget> _slotVenueWidgets(BuildContext context, BookingTimeSlotModel s) {
    final cs = Theme.of(context).colorScheme;
    final widgets = <Widget>[];
    final locTitle = (s.locationType?.title ?? '').trim();
    if (locTitle.isNotEmpty) {
      widgets.add(
        Row(
          children: [
            Icon(
              locationTypeIcon(s.locationType?.value),
              size: 18,
              color: cs.primary,
            ),
            const SizedBox(width: 6),
            Expanded(child: Text(locTitle)),
          ],
        ),
      );
    }
    for (final line in [
      if ((s.address ?? '').trim().isNotEmpty) s.address!.trim(),
      if ((s.roomDetails ?? '').trim().isNotEmpty) s.roomDetails!.trim(),
      if ((s.virtualMeetingLink ?? '').trim().isNotEmpty)
        s.virtualMeetingLink!.trim(),
      if ((s.notes ?? '').trim().isNotEmpty) s.notes!.trim(),
    ]) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(line),
        ),
      );
    }
    return widgets;
  }

  List<Widget> _paymentRows(BuildContext context, BookingDetailModel b) {
    final l10n = AppLocalizations.of(context)!;
    final code = b.currencyCode ?? 'USD';
    final money = NumberFormat.simpleCurrency(name: code, decimalDigits: 2);
    final base = double.tryParse(b.basePrice ?? '0') ?? 0;
    final fee = double.tryParse(b.platformFeeAmount ?? '0') ?? 0;
    final total = double.tryParse(b.totalPrice) ?? 0;
    final rows = <Widget>[];
    if (fee > 0) {
      rows.add(Text('${l10n.businessBookingFeeBase}: ${money.format(base)}'));
      final rate = double.tryParse(b.platformFeeRate ?? '');
      final feeLabel = rate != null && rate > 0
          ? '${l10n.businessBookingFeePlatform} (${rate.toStringAsFixed(2)}%)'
          : l10n.businessBookingFeePlatform;
      rows.add(Text('$feeLabel: ${money.format(fee)}'));
      rows.add(const SizedBox(height: 4));
    }
    rows.add(Text('${l10n.businessBookingFeeTotal}: ${money.format(total)}'));
    final pay = b.paymentSummary;
    if (pay != null) {
      final payCode = pay.currencyCode ?? code;
      final payMoney =
          NumberFormat.simpleCurrency(name: payCode, decimalDigits: 2);
      final net = double.tryParse(pay.netCaptured) ?? 0;
      rows.add(const SizedBox(height: 4));
      rows.add(
        Text('${l10n.businessBookingNetCaptured}: ${payMoney.format(net)}'),
      );
    }
    return rows;
  }

  Widget? _clientDetails(BookingClientBrief client) {
    final rows = <String>[
      if (client.age != null) '${client.age} years old',
      if (client.sex != null) client.sex!.title,
      if ((client.phone ?? '').isNotEmpty) client.phone!,
      if ((client.email ?? '').isNotEmpty) client.email!,
    ];
    if (rows.isEmpty) return null;
    return Text(rows.join(' • '));
  }
}
