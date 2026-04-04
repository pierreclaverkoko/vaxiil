import 'package:flutter/material.dart';
import 'package:vaxiil_mobile/core/constants/app_constants.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';

/// White card with soft shadow and large corner radius.
class SoftCard extends StatelessWidget {
  const SoftCard({
    required this.child,
    super.key,
    this.padding,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusCard),
        boxShadow: AppTheme.cardShadow,
      ),
      child: child,
    );
  }
}
