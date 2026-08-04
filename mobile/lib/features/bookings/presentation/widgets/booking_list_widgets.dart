import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:heroicons/heroicons.dart';
import 'package:intl/intl.dart';
import 'package:vaxiil_mobile/core/utils/hero_icon_from_name.dart';
import 'package:vaxiil_mobile/features/bookings/data/booking_models.dart';
import 'package:vaxiil_mobile/features/bookings/presentation/widgets/booking_category_meta.dart';
import 'package:vaxiil_mobile/l10n/app_localizations.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/themes/vaxiil_text.dart';

HeroIcons categoryHeroIconForBooking(BookingListItemModel b) {
  final raw = b.serviceCategory?.icon;
  return heroIconFromDbName(
    raw != null && raw.isNotEmpty ? raw : null,
    fallback: HeroIcons.sparkles,
  );
}

String formatBookingListDate(DateTime? t) {
  if (t == null) return 'Date TBD';
  return DateFormat.yMMMd().format(t.toLocal());
}

String formatBookingListTime(DateTime? t) {
  if (t == null) return '—';
  return DateFormat.jm().format(t.toLocal());
}

/// Segmented control: two tabs (e.g. Upcoming / Past or Ongoing / Past).
class BookingListSegmentedTabs extends StatelessWidget {
  const BookingListSegmentedTabs({
    required this.selected,
    required this.onChanged,
    this.firstLabel = 'Upcoming',
    this.secondLabel = 'Past',
    super.key,
  });

  final int selected;
  final ValueChanged<int> onChanged;
  final String firstLabel;
  final String secondLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegButton(
              label: firstLabel,
              selected: selected == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _SegButton(
              label: secondLabel,
              selected: selected == 1,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegButton extends StatelessWidget {
  const _SegButton({
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
    final vt = VaxiilText.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? cs.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF141E17).withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: vt.categoryLabel.copyWith(
                fontSize: 15,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BookingUpcomingListCard extends StatelessWidget {
  const BookingUpcomingListCard({
    required this.booking,
    required this.vt,
    required this.cs,
    required this.confirmedBadgeColor,
    required this.stitchOrange,
    required this.onViewDetails,
    required this.onReschedule,
    super.key,
  });

  final BookingListItemModel booking;
  final VaxiilText vt;
  final ColorScheme cs;
  final Color confirmedBadgeColor;
  final Color stitchOrange;
  final VoidCallback onViewDetails;
  final VoidCallback onReschedule;

  bool get _isConfirmed =>
      booking.status?.value == 'F' || booking.status?.value == 'P';

  bool get _isPending =>
      booking.status?.value == 'Q' || booking.status?.value == 'D';

  bool get _isCancelled => booking.status?.value == 'X';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dateStr = formatBookingListDate(booking.earliestSlotStart);
    final timeStr = formatBookingListTime(booking.earliestSlotStart);
    final badgeColor = _isCancelled
        ? const Color(0xFFE8A838)
        : _isPending
            ? stitchOrange
            : confirmedBadgeColor;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: HeroIcon(
                      categoryHeroIconForBooking(booking),
                      style: HeroIconStyle.outline,
                      color: cs.primary,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.displayTitle,
                        style: vt.cardTitle.copyWith(fontSize: 20),
                      ),
                      BookingCategoryMeta(
                        category: booking.serviceCategory,
                        compact: true,
                      ),
                      if (booking.displayProviderSubtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          booking.displayProviderSubtitle!,
                          style: vt.discoverySubtitle.copyWith(
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        (booking.status?.title ?? 'Booking').toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: _isCancelled
                              ? const Color(0xFF5E2C00)
                              : Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _PaymentStatusBadge(
                      paymentState: booking.paymentState,
                      paidLabel: l10n.bookingPaidBadge,
                      unpaidLabel: l10n.bookingUnpaidBadge,
                      refundedLabel: l10n.bookingRefundedBadge,
                      processingLabel: l10n.bookingProcessingBadge,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  dateStr,
                  style: vt.categoryLabel.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 20),
                Icon(
                  Icons.schedule,
                  size: 18,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  timeStr,
                  style: vt.categoryLabel.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            if (_isPending) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.errorContainer.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: cs.error,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          booking.isPaid
                              ? l10n.bookingAwaitingApproval
                              : l10n.bookingActionRequired,
                          style: vt.categoryLabel.copyWith(
                            color: cs.error,
                            fontSize: 11,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      booking.isPaid
                          ? l10n.bookingAwaitingApprovalBody
                          : l10n.bookingActionRequiredBody,
                      style: vt.discoverySubtitle.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            if (_isConfirmed)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReschedule,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.onSurfaceVariant,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        side: BorderSide(color: cs.outlineVariant),
                      ),
                      child: Text(
                        'Reschedule',
                        style: vt.bookNow.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: onViewDetails,
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Text(l10n.bookingViewDetails),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onViewDetails,
                  style: FilledButton.styleFrom(
                    backgroundColor: stitchOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: Text(l10n.bookingViewDetails),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class BookingPastListCard extends StatelessWidget {
  const BookingPastListCard({
    required this.booking,
    required this.vt,
    required this.cs,
    required this.onRebook,
    super.key,
  });

  final BookingListItemModel booking;
  final VaxiilText vt;
  final ColorScheme cs;
  final VoidCallback onRebook;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final last = booking.earliestSlotStart ?? booking.createdAt;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: HeroIcon(
                    categoryHeroIconForBooking(booking),
                    style: HeroIconStyle.outline,
                    color: cs.primary,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.displayTitle,
                      style: vt.cardTitle.copyWith(
                        fontSize: 20,
                        color: cs.onSurface.withOpacity(0.85),
                      ),
                    ),
                    BookingCategoryMeta(
                      category: booking.serviceCategory,
                      compact: true,
                    ),
                    if (booking.displayProviderSubtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        booking.displayProviderSubtitle!,
                        style: vt.discoverySubtitle.copyWith(fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
              _PaymentStatusBadge(
                paymentState: booking.paymentState,
                paidLabel: l10n.bookingPaidBadge,
                unpaidLabel: l10n.bookingUnpaidBadge,
                refundedLabel: l10n.bookingRefundedBadge,
                processingLabel: l10n.bookingProcessingBadge,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LAST SESSION',
                      style: vt.categoryLabel.copyWith(
                        fontSize: 11,
                        letterSpacing: 1.5,
                        color: cs.onSurfaceVariant.withOpacity(0.65),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      last != null
                          ? DateFormat.yMMMd().format(last.toLocal())
                          : '—',
                      style: vt.categoryLabel.copyWith(
                        fontSize: 14,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: booking.serviceId.isEmpty ? null : onRebook,
                style: FilledButton.styleFrom(
                  backgroundColor: cs.secondaryContainer,
                  foregroundColor: cs.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.replay, size: 18, color: cs.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Rebook',
                      style: vt.bookNow.copyWith(color: cs.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentStatusBadge extends StatelessWidget {
  const _PaymentStatusBadge({
    required this.paymentState,
    required this.paidLabel,
    required this.unpaidLabel,
    required this.refundedLabel,
    required this.processingLabel,
  });

  final String paymentState;
  final String paidLabel;
  final String unpaidLabel;
  final String refundedLabel;
  final String processingLabel;

  @override
  Widget build(BuildContext context) {
    final isPaid = paymentState == 'paid';
    final isRefunded = paymentState == 'refunded';
    final isProcessing = paymentState == 'processing';
    final Color bg;
    final Color fg;
    final String label;
    if (isPaid) {
      bg = const Color(0xFFC8E6C9);
      fg = const Color(0xFF0D631B);
      label = paidLabel;
    } else if (isProcessing) {
      bg = const Color(0xFFD6EAF8);
      fg = const Color(0xFF0B3D5C);
      label = processingLabel;
    } else if (isRefunded) {
      bg = const Color(0xFFFFF4ED);
      fg = const Color(0xFF5E2C00);
      label = refundedLabel;
    } else {
      bg = const Color(0xFFFFF4ED);
      fg = const Color(0xFF5E2C00);
      label = unpaidLabel;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: fg,
        ),
      ),
    );
  }
}

class BookingListEmptyAll extends StatelessWidget {
  const BookingListEmptyAll({
    required this.vt,
    required this.cs,
    required this.title,
    required this.subtitle,
    super.key,
  });

  final VaxiilText vt;
  final ColorScheme cs;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HeroIcon(
            HeroIcons.calendarDays,
            style: HeroIconStyle.outline,
            size: 64,
            color: cs.primary,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: vt.discoverySubtitle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class BookingListEmptyTab extends StatelessWidget {
  const BookingListEmptyTab({
    required this.vt,
    required this.cs,
    required this.message,
    required this.detail,
    super.key,
  });

  final VaxiilText vt;
  final ColorScheme cs;
  final String message;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HeroIcon(
            HeroIcons.calendarDays,
            style: HeroIconStyle.outline,
            size: 56,
            color: cs.primary.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            style: vt.discoverySubtitle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
