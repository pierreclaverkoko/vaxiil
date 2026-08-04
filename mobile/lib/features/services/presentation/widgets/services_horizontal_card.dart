import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:vaxiil_mobile/features/services/data/service_catalog_models.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/themes/vaxiil_text.dart';
import 'package:vaxiil_mobile/shared/widgets/service_card_location_meta.dart';

/// Compact horizontal card for Featured / Favorites / Nearby carousels on
/// the services discovery page — image, rating pill, heart, title, price,
/// mint “Book now”.
class ServicesHorizontalCard extends StatelessWidget {
  const ServicesHorizontalCard({
    required this.item,
    required this.priceMain,
    required this.isFavorite,
    required this.onOpen,
    required this.onFavoriteTap,
    super.key,
  });

  final ServiceListItemModel item;
  final String priceMain;
  final bool isFavorite;
  final VoidCallback onOpen;
  final VoidCallback onFavoriteTap;

  static const double _cardWidth = 280;
  /// Matches [ServicesPage] horizontal list height so layout never overflows.
  static const double cardHeight = 340;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vt = VaxiilText.of(context);
    final ratingText = item.ratingLabel;

    return SizedBox(
      width: _cardWidth,
      height: cardHeight,
      child: Material(
        color: AppTheme.surfaceColor,
        elevation: 0,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
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
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Material(
                            color: Colors.white.withOpacity(0.92),
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: onFavoriteTap,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: HeroIcon(
                                  HeroIcons.heart,
                                  style: isFavorite
                                      ? HeroIconStyle.solid
                                      : HeroIconStyle.outline,
                                  size: 20,
                                  color:
                                      isFavorite ? cs.error : cs.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (ratingText != null)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.92),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star_rounded,
                                    size: 16,
                                    color: cs.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    ratingText,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: cs.primary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: vt.cardTitle.copyWith(
                        fontSize: 15,
                        height: 1.25,
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    ServiceCardLocationMeta(
                      cityName: item.cityName,
                      locationTypes: item.effectiveLocationTypes,
                      compact: true,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: RichText(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: vt.pricePrimary.copyWith(fontSize: 18),
                              children: [
                                TextSpan(text: priceMain),
                                TextSpan(
                                  text: ' / session',
                                  style: vt.priceSuffix,
                                ),
                              ],
                            ),
                          ),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.ctaFill,
                            foregroundColor: AppTheme.onCtaFill,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          onPressed: onOpen,
                          child: const Text(
                            'Book now',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
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
      ),
    );
  }
}
