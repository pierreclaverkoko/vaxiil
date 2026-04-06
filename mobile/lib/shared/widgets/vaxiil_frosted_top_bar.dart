import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/themes/vaxiil_text.dart';

/// Frosted, blurred header (Stitch discovery top app bar): menu, optional brand
/// logo image or text title, profile avatar. Uses [ThemeData.colorScheme] and
/// [VaxiilText].
class VaxiilFrostedTopBar extends StatelessWidget {
  const VaxiilFrostedTopBar({
    required this.topPadding,
    required this.onMenu,
    required this.onAvatarTap,
    this.avatarUrl,
    this.title = 'Vaxiil',
    this.logoUrl,
    super.key,
  });

  final double topPadding;
  final VoidCallback onMenu;
  final VoidCallback onAvatarTap;
  final String? avatarUrl;
  final String title;

  /// When set, shown instead of [title] (Stitch “Home Discovery with Logo”).
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vt = VaxiilText.of(context);

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
          child: Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                onPressed: onMenu,
                icon: Icon(Icons.menu, color: cs.primary, size: 26),
              ),
              const SizedBox(width: 4),
              if (logoUrl != null && logoUrl!.isNotEmpty)
                _BrandLogo(url: logoUrl!)
              else
                Text(title, style: vt.frostedAppBarTitle),
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
                              child: Icon(Icons.person, color: cs.primary),
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
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo({required this.url});

  final String url;

  static const double _h = 32;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: _h,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
        placeholder: (_, __) => SizedBox(
          height: _h,
          width: 96,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.primary,
              ),
            ),
          ),
        ),
        errorWidget: (_, __, ___) => Text(
          'Vaxiil',
          style: VaxiilText.of(context).frostedAppBarTitle,
        ),
      ),
    );
  }
}
