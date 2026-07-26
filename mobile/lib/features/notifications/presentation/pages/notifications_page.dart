import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/features/bookings/data/bookings_repository.dart';
import 'package:vaxiil_mobile/features/notifications/data/notification_models.dart';
import 'package:vaxiil_mobile/features/notifications/data/notifications_repository.dart';
import 'package:vaxiil_mobile/l10n/app_localizations.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_site_footer.dart';

/// Stitch notifications inbox: groups, mark-read, booking/message deep links.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    this.organizationId,
    this.scope = 'personal',
  });

  /// When set, loads the organization-scoped feed.
  final String? organizationId;

  /// `personal` | `staff` — used when [organizationId] is absent.
  final String scope;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static const _unreadDot = Color(0xFFF59E0B);

  List<NotificationModel> _items = [];
  Object? _error;
  var _loading = true;
  var _acting = false;

  bool get _isOrgScoped {
    final id = widget.organizationId;
    return id != null && id.isNotEmpty;
  }

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
      final list = await sl<NotificationsRepository>().list(
        organizationId: _isOrgScoped ? widget.organizationId : null,
        scope: widget.scope,
      );
      if (!mounted) return;
      setState(() {
        _items = list;
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

  bool get _hasUnread => _items.any((n) => n.isUnread);

  List<_NotificationGroup> _groups(AppLocalizations l10n) {
    final today = <NotificationModel>[];
    final yesterday = <NotificationModel>[];
    final earlier = <NotificationModel>[];
    final now = DateTime.now();
    final startToday = DateTime(now.year, now.month, now.day);
    final startYesterday = startToday.subtract(const Duration(days: 1));

    for (final n in _items) {
      final created = n.createdAt?.toLocal();
      if (created == null) {
        earlier.add(n);
        continue;
      }
      if (!created.isBefore(startToday)) {
        today.add(n);
      } else if (!created.isBefore(startYesterday)) {
        yesterday.add(n);
      } else {
        earlier.add(n);
      }
    }

    return [
      if (today.isNotEmpty)
        _NotificationGroup(label: l10n.notificationsToday, items: today),
      if (yesterday.isNotEmpty)
        _NotificationGroup(
          label: l10n.notificationsYesterday,
          items: yesterday,
        ),
      if (earlier.isNotEmpty)
        _NotificationGroup(
          label: l10n.notificationsEarlier,
          items: earlier,
        ),
    ];
  }

  Future<void> _markAllRead() async {
    if (_acting || !_hasUnread) return;
    setState(() => _acting = true);
    try {
      await sl<NotificationsRepository>().markAllRead(
        organizationId: _isOrgScoped ? widget.organizationId : null,
        scope: widget.scope,
      );
      if (!mounted) return;
      final now = DateTime.now();
      setState(() {
        _items = _items
            .map((n) => n.isUnread ? n.copyWith(readAt: now) : n)
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _open(NotificationModel n) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      if (n.isUnread) {
        final updated = await sl<NotificationsRepository>().markRead(n.id);
        if (!mounted) return;
        setState(() {
          _items = _items.map((row) => row.id == n.id ? updated : row).toList();
        });
      }
      final conversationId = n.conversationId;
      if (conversationId != null && conversationId.isNotEmpty) {
        if (!mounted) return;
        await context.push('${AppRoutes.messages}/$conversationId');
        return;
      }
      final bookingId = n.bookingId;
      if (bookingId == null || bookingId.isEmpty) {
        return;
      }
      final scopedOrgId = widget.organizationId;
      if (scopedOrgId != null && scopedOrgId.isNotEmpty) {
        if (!mounted) return;
        await context.push(
          '${AppRoutes.businessBookingDetail}'
          '?id=$bookingId&organizationId=$scopedOrgId',
        );
        return;
      }
      if (NotificationModel.isOrgFacingKind(n.kind)) {
        try {
          final booking = await sl<BookingsRepository>().get(bookingId);
          if (!mounted) return;
          if (booking.organizationId.isNotEmpty) {
            await context.push(
              '${AppRoutes.businessBookingDetail}'
              '?id=$bookingId&organizationId=${booking.organizationId}',
            );
            return;
          }
        } catch (_) {
          // Fall through to consumer booking detail.
        }
      }
      if (!mounted) return;
      await context.push('${AppRoutes.bookingDetails}?id=$bookingId');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  IconData _iconFor(String kind) {
    switch (kind) {
      case 'booking_confirmed':
      case 'reschedule_accepted':
        return Icons.event_available;
      case 'booking_received':
        return Icons.event_note;
      case 'booking_cancelled':
      case 'reschedule_declined':
        return Icons.event_busy;
      case 'reschedule_proposed':
        return Icons.schedule;
      case 'message_invite':
        return Icons.person_add_alt_1_outlined;
      case 'message_received':
        return Icons.chat_bubble_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _formatTime(DateTime? createdAt) {
    if (createdAt == null) return '';
    final local = createdAt.toLocal();
    final now = DateTime.now();
    final startToday = DateTime(now.year, now.month, now.day);
    if (!local.isBefore(startToday)) {
      final diff = now.difference(local);
      if (diff.inMinutes < 1) return DateFormat.jm().format(local);
      if (diff.inHours < 1) return '${diff.inMinutes}m';
      if (diff.inHours < 12) return '${diff.inHours}h';
      return DateFormat.jm().format(local);
    }
    return DateFormat.MMMd().format(local);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final groups = _groups(l10n);
    final title = _isOrgScoped
        ? l10n.notificationsBusinessTitle
        : widget.scope == 'staff'
            ? l10n.notificationsStaffTitle
            : l10n.notificationsTitle;
    final subtitle = _isOrgScoped
        ? l10n.notificationsBusinessSubtitle
        : l10n.notificationsSubtitle;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_hasUnread)
            TextButton(
              onPressed: _acting ? null : _markAllRead,
              child: Text(l10n.notificationsMarkAllRead),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  ResponsiveContent(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        const SizedBox(height: 24),
                        if (_error != null) ...[
                          Text(
                            l10n.notificationsLoadError,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _err(_error!),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: _load,
                            child: Text(l10n.notificationsRetry),
                          ),
                        ] else if (_items.isEmpty)
                          _EmptyState(
                            message: l10n.notificationsEmpty,
                            ctaLabel: _isOrgScoped
                                ? l10n.notificationsBusinessEmptyCta
                                : l10n.notificationsEmptyCta,
                            onCta: () {
                              if (_isOrgScoped) {
                                context.push(
                                  '${AppRoutes.businessProfile}?id=${widget.organizationId}',
                                );
                              } else {
                                context.go(AppRoutes.home);
                              }
                            },
                            cs: cs,
                          )
                        else
                          ...groups.map(
                            (g) => _GroupSection(
                              label: g.label,
                              items: g.items,
                              acting: _acting,
                              iconFor: _iconFor,
                              formatTime: _formatTime,
                              unreadDot: _unreadDot,
                              viewDetailsLabel: l10n.notificationsViewDetails,
                              markReadLabel: l10n.notificationsMarkRead,
                              onOpen: _open,
                              cs: cs,
                            ),
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

class _NotificationGroup {
  const _NotificationGroup({required this.label, required this.items});

  final String label;
  final List<NotificationModel> items;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.message,
    required this.ctaLabel,
    required this.onCta,
    required this.cs,
  });

  final String message;
  final String ctaLabel;
  final VoidCallback onCta;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 48,
            color: cs.primary,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onCta,
            child: Text(
              ctaLabel,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.label,
    required this.items,
    required this.acting,
    required this.iconFor,
    required this.formatTime,
    required this.unreadDot,
    required this.viewDetailsLabel,
    required this.markReadLabel,
    required this.onOpen,
    required this.cs,
  });

  final String label;
  final List<NotificationModel> items;
  final bool acting;
  final IconData Function(String kind) iconFor;
  final String Function(DateTime? createdAt) formatTime;
  final Color unreadDot;
  final String viewDetailsLabel;
  final String markReadLabel;
  final Future<void> Function(NotificationModel n) onOpen;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.4,
                    color: AppTheme.textSecondary,
                  ),
            ),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (n) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _NotificationCard(
                notification: n,
                acting: acting,
                icon: iconFor(n.kind),
                timeLabel: formatTime(n.createdAt),
                unreadDot: unreadDot,
                viewDetailsLabel: viewDetailsLabel,
                markReadLabel: markReadLabel,
                onOpen: () => onOpen(n),
                cs: cs,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.acting,
    required this.icon,
    required this.timeLabel,
    required this.unreadDot,
    required this.viewDetailsLabel,
    required this.markReadLabel,
    required this.onOpen,
    required this.cs,
  });

  final NotificationModel notification;
  final bool acting;
  final IconData icon;
  final String timeLabel;
  final Color unreadDot;
  final String viewDetailsLabel;
  final String markReadLabel;
  final VoidCallback onOpen;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final unread = notification.isUnread;
    final hasDeepLink = (notification.bookingId != null &&
            notification.bookingId!.isNotEmpty) ||
        (notification.conversationId != null &&
            notification.conversationId!.isNotEmpty);

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: acting ? null : onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: unread
                ? Border.all(color: cs.primary.withOpacity(0.12))
                : null,
          ),
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cs.primary.withOpacity(0.1),
                    ),
                    child: Icon(icon, color: cs.primary, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (timeLabel.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Padding(
                                padding: EdgeInsets.only(
                                  right: unread ? 16 : 0,
                                ),
                                child: Text(
                                  timeLabel,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textSecondary,
                                      ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.body,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondary,
                                height: 1.45,
                              ),
                        ),
                        if (hasDeepLink || unread) ...[
                          const SizedBox(height: 12),
                          if (hasDeepLink)
                            FilledButton(
                              onPressed: acting ? null : onOpen,
                              style: FilledButton.styleFrom(
                                backgroundColor: cs.primaryContainer,
                                foregroundColor: cs.onPrimaryContainer,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                              ),
                              child: Text(viewDetailsLabel),
                            )
                          else
                            OutlinedButton(
                              onPressed: acting ? null : onOpen,
                              child: Text(markReadLabel),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (unread)
                Positioned(
                  top: 4,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: unreadDot,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: unreadDot.withOpacity(0.4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
