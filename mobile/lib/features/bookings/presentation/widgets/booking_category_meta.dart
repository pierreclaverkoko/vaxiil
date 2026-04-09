import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:vaxiil_mobile/core/utils/hero_icon_from_name.dart';
import 'package:vaxiil_mobile/features/services/data/service_catalog_models.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/themes/vaxiil_text.dart';

/// Category name + Heroicon under the service title (bookings list / detail).
class BookingCategoryMeta extends StatelessWidget {
  const BookingCategoryMeta({
    required this.category,
    super.key,
    this.compact = false,
    this.centered = false,
  });

  final ServiceCategoryBrief? category;
  final bool compact;

  /// When true, row is centered (e.g. session history title block).
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final c = category;
    if (c == null || c.name.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final cs = Theme.of(context).colorScheme;
    final vt = VaxiilText.of(context);
    final iconData = heroIconFromDbName(
      c.icon.isEmpty ? null : c.icon,
      fallback: HeroIcons.squares2x2,
    );
    final textStyle = (compact
            ? vt.categoryLabel
            : vt.discoverySubtitle.copyWith(fontSize: 14))
        .copyWith(
      color: AppTheme.textSecondary,
      fontWeight: FontWeight.w600,
    );
    final icon = HeroIcon(
      iconData,
      style: HeroIconStyle.outline,
      size: compact ? 15 : 17,
      color: cs.primary,
    );
    final gap = SizedBox(width: compact ? 5 : 6);
    final label = Text(c.name, style: textStyle);
    return Padding(
      padding: EdgeInsets.only(top: compact ? 2 : 4),
      child: centered
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [icon, gap, label],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                icon,
                gap,
                Expanded(child: label),
              ],
            ),
    );
  }
}
