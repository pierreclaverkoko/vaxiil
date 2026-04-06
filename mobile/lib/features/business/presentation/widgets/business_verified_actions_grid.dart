import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';

/// 2×2 circular actions for verified organizations (Services, Bookings, Team, Settings).
class BusinessVerifiedActionsGrid extends StatelessWidget {
  const BusinessVerifiedActionsGrid({
    required this.organizationId,
    super.key,
  });

  final String organizationId;

  @override
  Widget build(BuildContext context) {
    final items = <_ActionItem>[
      _ActionItem(
        label: 'Services',
        icon: HeroIcons.sparkles,
        background: AppTheme.ctaFill,
        foreground: AppTheme.onCtaFill,
        onTap: () => context.push(
          '${AppRoutes.businessServices}?id=$organizationId',
        ),
      ),
      _ActionItem(
        label: 'Bookings',
        icon: HeroIcons.calendarDays,
        background: AppTheme.accentPeach,
        foreground: AppTheme.onAccentPeach,
        onTap: () => context.push(
          '${AppRoutes.businessBookings}?id=$organizationId',
        ),
      ),
      _ActionItem(
        label: 'Team',
        icon: HeroIcons.userGroup,
        background: AppTheme.accentPeach,
        foreground: AppTheme.onAccentPeach,
        onTap: () => context.push(
          '${AppRoutes.businessPractitioners}?id=$organizationId',
        ),
      ),
      _ActionItem(
        label: 'Settings',
        icon: HeroIcons.cog6Tooth,
        background: AppTheme.ctaFill,
        foreground: AppTheme.onCtaFill,
        onTap: () => context.push(
          '${AppRoutes.businessSettings}?id=$organizationId',
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var row = 0; row < 2; row++)
            Padding(
              padding: EdgeInsets.only(bottom: row == 0 ? 16 : 0),
              child: Row(
                children: [
                  Expanded(
                    child: _circleAction(context, items[row * 2]),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _circleAction(context, items[row * 2 + 1]),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _circleAction(BuildContext context, _ActionItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: item.background,
                  shape: BoxShape.circle,
                  boxShadow: AppTheme.cardShadow,
                ),
                alignment: Alignment.center,
                child: HeroIcon(
                  item.icon,
                  style: HeroIconStyle.outline,
                  color: item.foreground,
                  size: 32,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionItem {
  const _ActionItem({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final HeroIcons icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;
}
