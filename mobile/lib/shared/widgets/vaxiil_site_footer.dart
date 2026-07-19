import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/shared/themes/vaxiil_text.dart';
import 'package:vaxiil_mobile/shared/utils/responsive.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_logo.dart';

/// Site footer for expanded (md+) layouts — Privacy / Terms / Help + copyright.
class VaxiilSiteFooter extends StatelessWidget {
  const VaxiilSiteFooter({super.key});

  @override
  Widget build(BuildContext context) {
    if (!context.isExpandedShell) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;
    final vt = VaxiilText.of(context);
    final muted = cs.onSurfaceVariant.withOpacity(0.7);

    return Container(
      width: double.infinity,
      color: cs.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 24,
            runSpacing: 16,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const VaxiilLogo(
                    height: 28,
                    showPlate: false,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Vaxiil',
                    style: vt.frostedAppBarTitle.copyWith(
                      color: cs.primary,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 32,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _FooterLink(
                    label: 'Privacy Policy',
                    onTap: () => context.push(AppRoutes.privacy),
                    color: muted,
                  ),
                  _FooterLink(
                    label: 'Terms of Service',
                    onTap: () => context.push(AppRoutes.terms),
                    color: muted,
                  ),
                  _FooterLink(
                    label: 'Help Center',
                    onTap: () => context.push(AppRoutes.help),
                    color: muted,
                  ),
                ],
              ),
              Text(
                '© ${DateTime.now().year} Vaxiil. '
                'All rights reserved.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({
    required this.label,
    required this.onTap,
    required this.color,
  });

  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}

/// Centers [child] with a max width that grows on md/lg (Stitch content rails).
class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    required this.child,
    this.maxWidth,
    this.padding,
    this.narrowMaxWidth = 672,
    super.key,
  });

  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;
  final double narrowMaxWidth;

  @override
  Widget build(BuildContext context) {
    final max = maxWidth ??
        ResponsiveUtils.contentMaxWidth(context, narrow: narrowMaxWidth);
    final pad = padding ??
        EdgeInsets.symmetric(
          horizontal: context.isMdUp ? 32 : 24,
        );

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: max),
        child: Padding(padding: pad, child: child),
      ),
    );
  }
}
