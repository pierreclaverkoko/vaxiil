import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/features/bookings/data/bookings_repository.dart';
import 'package:vaxiil_mobile/features/payments/data/payment_transaction_models.dart';
import 'package:vaxiil_mobile/l10n/app_localizations.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/themes/vaxiil_text.dart';
import 'package:vaxiil_mobile/shared/widgets/choice_enum_widget.dart';

class TransactionsListPage extends StatefulWidget {
  const TransactionsListPage({super.key});

  @override
  State<TransactionsListPage> createState() => _TransactionsListPageState();
}

class _TransactionsListPageState extends State<TransactionsListPage> {
  final _rows = <PaymentTransactionItem>[];
  String _statusFilter = '';
  bool _loading = true;
  String? _error;
  int _page = 1;
  bool _hasMore = true;
  bool _loadingMore = false;
  final _refreshingRefs = <String>{};

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
        _hasMore = true;
      });
    } else {
      if (!_hasMore || _loadingMore) return;
      setState(() => _loadingMore = true);
    }
    try {
      final page = reset ? 1 : _page;
      final items = await sl<BookingsRepository>().listTransactions(
        page: page,
        status: _statusFilter.isEmpty ? null : _statusFilter,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _rows
            ..clear()
            ..addAll(items);
        } else {
          _rows.addAll(items);
        }
        _hasMore = items.length >= 20;
        _page = page + 1;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      final message = e is Failure ? e.message : e.toString();
      setState(() {
        _error = message;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _onFilter(String value) {
    if (_statusFilter == value) return;
    setState(() => _statusFilter = value);
    _load(reset: true);
  }

  void _openBooking(PaymentTransactionItem row) {
    final id = row.bookingId;
    if (id == null || id.isEmpty) return;
    context.push('${AppRoutes.bookingDetails}?id=$id');
  }

  Future<void> _refreshRow(PaymentTransactionItem row) async {
    final ref = row.clientReference;
    if (ref.isEmpty || _refreshingRefs.contains(ref)) return;
    setState(() => _refreshingRefs.add(ref));
    try {
      final updated = await sl<BookingsRepository>().refreshTransaction(ref);
      if (!mounted) return;
      setState(() {
        final idx = _rows.indexWhere((r) => r.clientReference == ref);
        if (idx >= 0) {
          _rows[idx] = updated;
        }
        _refreshingRefs.remove(ref);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _refreshingRefs.remove(ref));
      final l10n = AppLocalizations.of(context);
      final message = e is Failure ? e.message : l10n.transactionsRefreshFailed;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final vt = VaxiilText.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(l10n.transactionsTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              l10n.transactionsSubtitle,
              style: vt.discoverySubtitle,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FilterChip(
                  label: l10n.transactionsFilterAll,
                  selected: _statusFilter.isEmpty,
                  onTap: () => _onFilter(''),
                ),
                _FilterChip(
                  label: l10n.transactionsStatusSucceeded,
                  selected: _statusFilter == 'S',
                  onTap: () => _onFilter('S'),
                ),
                _FilterChip(
                  label: l10n.transactionsStatusPending,
                  selected: _statusFilter == 'N',
                  onTap: () => _onFilter('N'),
                ),
                _FilterChip(
                  label: l10n.transactionsStatusProcessing,
                  selected: _statusFilter == 'G',
                  onTap: () => _onFilter('G'),
                ),
                _FilterChip(
                  label: l10n.transactionsStatusFailed,
                  selected: _statusFilter == 'F',
                  onTap: () => _onFilter('F'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => _load(reset: true),
                      child: Text(l10n.transactionsRetry),
                    ),
                  ],
                ),
              )
            else if (_rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 56, color: cs.primary),
                    const SizedBox(height: 12),
                    Text(
                      l10n.transactionsEmpty,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else ...[
              for (final row in _rows) ...[
                _TransactionCard(
                  row: row,
                  onTap: row.bookingId != null ? () => _openBooking(row) : null,
                  onRefresh: row.canRefreshStatus
                      ? () => _refreshRow(row)
                      : null,
                  refreshing: _refreshingRefs.contains(row.clientReference),
                  viewBookingLabel: l10n.transactionsViewBooking,
                  refreshLabel: l10n.transactionsRefreshStatus,
                ),
                const SizedBox(height: 14),
              ],
              if (_hasMore)
                Center(
                  child: TextButton(
                    onPressed: _loadingMore ? null : () => _load(reset: false),
                    child: Text(
                      _loadingMore
                          ? l10n.transactionsLoading
                          : l10n.transactionsLoadMore,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
    return Material(
      color: selected ? cs.primary : cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? cs.onPrimary : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

IconData _methodIcon(PaymentTransactionItem row) {
  switch (row.paymentMethod?.methodType?.value) {
    case 'B':
      return Icons.account_balance_outlined;
    case 'M':
      return Icons.smartphone_outlined;
    case 'F':
      return Icons.payments_outlined;
    case 'C':
      return Icons.currency_bitcoin;
    default:
      return row.purpose?.value == 'W'
          ? Icons.account_balance_wallet_outlined
          : Icons.payments_outlined;
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.row,
    required this.viewBookingLabel,
    required this.refreshLabel,
    required this.refreshing,
    this.onRefresh,
    this.onTap,
  });

  final PaymentTransactionItem row;
  final String viewBookingLabel;
  final String refreshLabel;
  final VoidCallback? onRefresh;
  final bool refreshing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vt = VaxiilText.of(context);
    final method = row.paymentMethod;
    final logoUrl = method?.logoUrl;
    final dateStr = row.createdAt != null
        ? DateFormat.yMMMd().add_jm().format(row.createdAt!.toLocal())
        : null;
    final typeTitle = method?.methodType?.title;

    return Material(
      color: AppTheme.surfaceColor,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.cardShadow,
            color: AppTheme.surfaceColor,
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: logoUrl != null && logoUrl.isNotEmpty
                        ? Image.network(
                            logoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              _methodIcon(row),
                              color: cs.primary,
                            ),
                          )
                        : Icon(_methodIcon(row), color: cs.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.amountLabel,
                          style: vt.cardTitle.copyWith(fontSize: 18),
                        ),
                        if (method != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            method.name,
                            style: vt.discoverySubtitle.copyWith(fontSize: 14),
                          ),
                        ] else if (row.purpose != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            row.purpose!.title,
                            style: vt.discoverySubtitle.copyWith(fontSize: 14),
                          ),
                        ],
                        if (row.accountIdentifier.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            row.accountIdentifier,
                            style: vt.categoryLabel.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (onRefresh != null)
                        IconButton(
                          tooltip: refreshLabel,
                          onPressed: refreshing ? null : onRefresh,
                          icon: refreshing
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: cs.primary,
                                  ),
                                )
                              : Icon(
                                  Icons.refresh,
                                  color: cs.primary,
                                ),
                        ),
                      if (row.status != null) ChoiceEnumWidget(choice: row.status),
                      if (row.purpose != null) ...[
                        const SizedBox(height: 6),
                        ChoiceEnumWidget(choice: row.purpose),
                      ],
                    ],
                  ),
                ],
              ),
              if (dateStr != null ||
                  typeTitle != null ||
                  row.kind != null ||
                  onTap != null) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    if (dateStr != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            dateStr,
                            style: vt.categoryLabel.copyWith(
                              color: cs.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    if (typeTitle != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _methodIcon(row),
                            size: 16,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            typeTitle,
                            style: vt.categoryLabel.copyWith(
                              color: cs.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      )
                    else if (row.kind != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.category_outlined,
                            size: 16,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            row.kind!.title,
                            style: vt.categoryLabel.copyWith(
                              color: cs.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    if (onTap != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_outlined,
                            size: 16,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            viewBookingLabel,
                            style: vt.categoryLabel.copyWith(
                              color: cs.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
