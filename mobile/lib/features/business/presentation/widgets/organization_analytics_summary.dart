import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/features/business/data/organization_models.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/widgets/soft_card.dart';

/// Inline summary of organization analytics (total bookings, revenue).
class OrganizationAnalyticsSummary extends StatelessWidget {
  const OrganizationAnalyticsSummary({
    required this.organizationId,
    required this.analytics,
    this.onViewDetails,
    this.showDetailsButton = true,
    this.heading = 'Analytics',
    this.showLiveBadge = false,
    super.key,
  });

  final String organizationId;
  final OrganizationAnalyticsModel analytics;
  final VoidCallback? onViewDetails;

  /// When false, the Details link is hidden (e.g. on the full-screen analytics page).
  final bool showDetailsButton;

  /// Card title (e.g. `Insights` on company hub).
  final String heading;

  /// Shows a small “LIVE” chip next to the title (Stitch company hub).
  final bool showLiveBadge;

  @override
  Widget build(BuildContext context) {
    final a = analytics;
    final cs = Theme.of(context).colorScheme;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const HeroIcon(
                HeroIcons.chartBar,
                style: HeroIconStyle.outline,
                color: AppTheme.primaryVariant,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  heading,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (showLiveBadge)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'LIVE',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: cs.onPrimaryContainer,
                          ),
                    ),
                  ),
                ),
              if (showDetailsButton)
                TextButton(
                  onPressed: onViewDetails ??
                      () => context.push(
                            '${AppRoutes.businessAnalytics}?id=$organizationId',
                          ),
                  child: const Text('Details'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _metric(context, 'Total bookings', '${a.totalBookings}'),
          _metric(
            context,
            'Revenue',
            '${a.revenue} ${a.currency ?? ''}'.trim(),
          ),
          if (a.note != null) ...[
            const SizedBox(height: 12),
            Text(
              a.note!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _metric(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
