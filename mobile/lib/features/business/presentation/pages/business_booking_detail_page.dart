import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/features/bookings/data/booking_models.dart';
import 'package:vaxiil_mobile/features/bookings/data/bookings_repository.dart';
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

  bool get _canCancelReschedule {
    final s = _booking?.status?.value;
    if (s == null) return false;
    return !{'M', 'X', 'N'}.contains(s);
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
              ? 'Booking cancelled. $amt ${cur ?? ''} credited to refund wallet.'
                  .trim()
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

  Future<void> _reschedule() async {
    final b = _booking;
    if (b == null) return;
    final slot = b.timeSlots.isNotEmpty ? b.timeSlots.first : null;
    var start = slot?.startTime ?? DateTime.now().add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final tod = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(start),
    );
    if (tod == null || !mounted) return;
    start = DateTime(
      date.year,
      date.month,
      date.day,
      tod.hour,
      tod.minute,
    );
    final end = start.add(const Duration(hours: 1));
    setState(() => _busy = true);
    try {
      await sl<BookingsRepository>().reschedule(widget.bookingId, [
        {
          'start_time': start.toUtc().toIso8601String(),
          'end_time': end.toUtc().toIso8601String(),
          'location_type': 'O',
        },
      ]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking rescheduled')),
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
                                  Text(
                                    b.status?.title ?? '',
                                    style: TextStyle(
                                      color: cs.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
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
                                  if (b.paymentSummary != null)
                                    Text(
                                      'Net captured: ${b.paymentSummary!.netCaptured} '
                                      '${b.paymentSummary!.currencyCode ?? b.currencyCode ?? ''}',
                                    )
                                  else
                                    Text(
                                      'Total (booking): ${b.totalPrice} ${b.currencyCode ?? ''}',
                                    ),
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
                                  const SizedBox(height: 16),
                                  Text(
                                    'Session',
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 8),
                                  ...b.timeSlots.map(
                                    (s) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Text(
                                        s.startTime != null
                                            ? '${DateFormat.yMMMd().format(s.startTime!.toLocal())} '
                                                '${DateFormat.jm().format(s.startTime!.toLocal())} — '
                                                '${s.endTime != null ? DateFormat.jm().format(s.endTime!.toLocal()) : '—'}'
                                            : '—',
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
      bottomNavigationBar: b == null || !_canCancelReschedule
          ? null
          : SafeArea(
              child: ResponsiveContent(
                narrowMaxWidth: 672,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    if (b.status?.value == 'Q') ...[
                      Expanded(
                        child: FilledButton(
                          onPressed: _busy
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
                    ] else if (b.status?.value == 'F') ...[
                      Expanded(
                        child: FilledButton(
                          onPressed: _busy
                              ? null
                              : () => _runStaffAction(
                                    'Booking completed',
                                    (repo) => repo.complete(widget.bookingId),
                                  ),
                          child: const Text('Complete'),
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy ? null : _reschedule,
                          child: const Text('Reschedule'),
                        ),
                      ),
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
              ),
            ),
    );
  }

  Widget? _clientDetails(BookingClientBrief client) {
    final rows = <String>[
      if ((client.phone ?? '').isNotEmpty) client.phone!,
      if ((client.email ?? '').isNotEmpty) client.email!,
      if (client.age != null) '${client.age} years old',
      if (client.sex != null) client.sex!.title,
    ];
    if (rows.isEmpty) return null;
    return Text(rows.join(' • '));
  }
}
