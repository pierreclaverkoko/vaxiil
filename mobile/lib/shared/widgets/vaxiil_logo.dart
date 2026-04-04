import 'package:flutter/material.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';

/// Branded logo with optional light plate for contrast on dark green headers.
class VaxiilLogo extends StatelessWidget {
  const VaxiilLogo({
    super.key,
    this.height = 72,
    this.width,
    this.showPlate = true,
    this.platePadding = const EdgeInsets.all(12),
    this.borderRadius = 28,
  });

  static const String assetPath = 'assets/logo.png';

  final double height;
  final double? width;
  final bool showPlate;
  final EdgeInsetsGeometry platePadding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      assetPath,
      height: height,
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );

    if (!showPlate) {
      return image;
    }

    final plateColor = Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : Colors.white;

    return Container(
      padding: platePadding,
      decoration: BoxDecoration(
        color: plateColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: AppTheme.cardShadow,
      ),
      child: image,
    );
  }
}
