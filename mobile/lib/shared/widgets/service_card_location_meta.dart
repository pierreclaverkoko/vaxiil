import 'package:flutter/material.dart';
import 'package:vaxiil_mobile/features/bookings/presentation/utils/booking_schedule_utils.dart';
import 'package:vaxiil_mobile/l10n/app_localizations.dart';

/// Town + accepted location-type icon tags for discovery/list service cards.
class ServiceCardLocationMeta extends StatelessWidget {
  const ServiceCardLocationMeta({
    required this.cityName,
    required this.locationTypes,
    this.dark = false,
    this.compact = false,
    super.key,
  });

  final String? cityName;
  final List<String> locationTypes;
  final bool dark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final town = (cityName ?? '').trim();
    final types = locationTypes
        .map((c) => c.trim().toUpperCase())
        .where((c) => c.isNotEmpty)
        .toList();
    if (town.isEmpty && types.isEmpty) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final muted = dark
        ? cs.onPrimaryContainer.withOpacity(0.8)
        : cs.onSurfaceVariant;
    final iconSize = compact ? 14.0 : 16.0;
    final gap = compact ? 6.0 : 8.0;

    return Padding(
      padding: EdgeInsets.only(top: compact ? 4 : 6, bottom: compact ? 0 : 2),
      child: Wrap(
        spacing: gap,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (town.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.place_outlined, size: iconSize, color: muted),
                const SizedBox(width: 2),
                Text(
                  town,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: muted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ...types.map((code) {
            final label = _locationLabel(l10n, code);
            return Tooltip(
              message: label,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: dark
                      ? Colors.white.withOpacity(0.12)
                      : cs.surfaceContainerHighest.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(locationTypeIcon(code), size: iconSize, color: muted),
                    const SizedBox(width: 3),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: muted,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  static String _locationLabel(AppLocalizations l10n, String code) {
    switch (code) {
      case 'H':
        return l10n.bookingLocationHome;
      case 'V':
        return l10n.bookingLocationVirtual;
      case 'B':
        return l10n.bookingLocationMobile;
      case 'O':
      default:
        return l10n.bookingLocationOffice;
    }
  }
}
