import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';

/// Circular 1:1 organization logo, or a building placeholder.
class OrgLogoAvatar extends StatelessWidget {
  const OrgLogoAvatar({
    super.key,
    this.logoUrl,
    this.size = 48,
    this.icon = HeroIcons.buildingOffice2,
  });

  final String? logoUrl;
  final double size;
  final HeroIcons icon;

  @override
  Widget build(BuildContext context) {
    final u = logoUrl?.trim();
    if (u != null && u.isNotEmpty) {
      return ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: CachedNetworkImage(
            imageUrl: u,
            fit: BoxFit.cover,
            placeholder: (_, __) => const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            errorWidget: (_, __, ___) => _fallback(),
          ),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.borderColor,
      ),
      alignment: Alignment.center,
      child: HeroIcon(
        icon,
        style: HeroIconStyle.outline,
        color: AppTheme.primaryVariant,
        size: size * 0.45,
      ),
    );
  }
}
