import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/themes/vaxiil_text.dart';
import 'package:vaxiil_mobile/shared/utils/responsive.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_logo.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_main_shell.dart';

/// Frosted header: menu + logo (+ expanded nav links) + avatar.
class VaxiilFrostedTopBar extends StatelessWidget {
  const VaxiilFrostedTopBar({
    required this.topPadding,
    required this.onMenu,
    required this.onAvatarTap,
    this.avatarUrl,
    this.title = 'Vaxiil',
    this.useLogo = true,
    this.navItems = kVaxiilMainNavItems,
    this.selectedNavIndex,
    this.onNavTap,
    this.showMenuWhenExpanded = true,
    super.key,
  });

  final double topPadding;
  final VoidCallback onMenu;
  final VoidCallback onAvatarTap;
  final String? avatarUrl;
  final String title;

  /// When true, shows [VaxiilLogo] instead of [title] text.
  final bool useLogo;

  final List<VaxiilMainNavItem> navItems;
  final int? selectedNavIndex;
  final ValueChanged<int>? onNavTap;

  /// Keep hamburger on large screens (drawer still useful for secondary links).
  final bool showMenuWhenExpanded;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vt = VaxiilText.of(context);
    final expanded = context.isExpandedShell;
    final logoHeight = context.isMdUp ? 40.0 : 32.0;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: topPadding,
            left: 24,
            right: 24,
            bottom: 12,
          ),
          decoration: AppTheme.frostedTopBarDecoration(cs),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Row(
                children: [
                  if (!expanded || showMenuWhenExpanded)
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      onPressed: onMenu,
                      icon: Icon(Icons.menu, color: cs.primary, size: 26),
                    ),
                  if (!expanded || showMenuWhenExpanded)
                    const SizedBox(width: 4),
                  if (useLogo)
                    VaxiilLogo(
                      height: logoHeight,
                      showPlate: false,
                    )
                  else
                    Text(title, style: vt.frostedAppBarTitle),
                  if (expanded && onNavTap != null) ...[
                    const SizedBox(width: 24),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(navItems.length, (i) {
                          final item = navItems[i];
                          final selected = selectedNavIndex == i;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: InkWell(
                              onTap: () => onNavTap!(i),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                child: Text(
                                  item.label == 'Home'
                                      ? 'Discover'
                                      : item.label,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: selected
                                            ? cs.primary
                                            : cs.onSurfaceVariant
                                                .withOpacity(0.7),
                                      ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ] else
                    const Spacer(),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onAvatarTap,
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.avatarBorderMuted,
                            width: 2,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: avatarUrl != null && avatarUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: avatarUrl!,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => ColoredBox(
                                  color: cs.surfaceContainerHigh,
                                  child: Center(
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: cs.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => ColoredBox(
                                  color: cs.surfaceContainerHigh,
                                  child: Icon(
                                    Icons.person,
                                    color: cs.primary,
                                  ),
                                ),
                              )
                            : ColoredBox(
                                color: cs.surfaceContainerHigh,
                                child: Icon(Icons.person, color: cs.primary),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
