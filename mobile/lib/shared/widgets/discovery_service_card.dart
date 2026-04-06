import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:vaxiil_mobile/features/services/data/service_catalog_models.dart';
import 'package:vaxiil_mobile/shared/themes/vaxiil_text.dart';

/// Vertical discovery card (home feed & services “browse” block): image, copy,
/// price row, Book — uses [ThemeData.colorScheme] and [VaxiilText].
class DiscoveryServiceCard extends StatelessWidget {
  const DiscoveryServiceCard({
    required this.item,
    required this.priceMain,
    required this.dark,
    required this.onOpen,
    super.key,
  });

  final ServiceListItemModel item;
  final String priceMain;
  final bool dark;
  final VoidCallback onOpen;

  static const double imageHeight = 256;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vt = VaxiilText.of(context);
    final titleStyle = dark
        ? Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            )
        : vt.cardTitle.copyWith(fontSize: 20);
    final bodyStyle = dark
        ? Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onPrimaryContainer.withOpacity(0.75),
            )
        : Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            );

    return Material(
      color: dark ? cs.primaryContainer : cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: dark ? 8 : 0,
      shadowColor: const Color(0xFF141E17).withOpacity(dark ? 0.2 : 0),
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: imageHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.primaryImage != null)
                    CachedNetworkImage(
                      imageUrl: item.primaryImage!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => ColoredBox(
                        color: cs.surfaceContainerHigh,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.primary,
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => ColoredBox(
                        color: cs.surfaceContainerHigh,
                        child: Icon(
                          Icons.spa_outlined,
                          size: 40,
                          color: cs.primary,
                        ),
                      ),
                    )
                  else
                    ColoredBox(
                      color: cs.surfaceContainerHigh,
                      child: Icon(
                        Icons.spa_outlined,
                        size: 40,
                        color: cs.primary,
                      ),
                    ),
                  if (dark)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              cs.primary.withOpacity(0.75),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (item.featured)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: cs.secondaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          "Editor's pick",
                          style: vt.discoverySubtitle.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: cs.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.description.isNotEmpty
                        ? item.description
                        : item.subCategory.name,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: bodyStyle,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: dark
                                ? Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    )
                                : vt.pricePrimary,
                            children: [
                              TextSpan(text: priceMain),
                              TextSpan(
                                text: ' / session',
                                style: dark
                                    ? Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: cs.onPrimaryContainer
                                              .withOpacity(0.65),
                                        )
                                    : vt.priceSuffix,
                              ),
                            ],
                          ),
                        ),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              dark ? cs.secondaryContainer : cs.primary,
                          foregroundColor:
                              dark ? cs.onSecondaryContainer : cs.onPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        onPressed: onOpen,
                        child: Text(
                          dark ? 'Select' : 'Book',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
