import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/core/utils/hero_icon_from_name.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vaxiil_mobile/features/services/data/service_catalog_models.dart';
import 'package:vaxiil_mobile/features/services/data/service_catalog_repository.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/themes/vaxiil_text.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_site_footer.dart';

/// Service detail — Stitch “Service Details with Accent”: hero, overlapping
/// title card, rating, feature bento, pill variants, provider row, tip, fixed CTA.
class ServiceDetailPage extends StatefulWidget {
  const ServiceDetailPage({required this.serviceId, super.key});

  final String serviceId;

  @override
  State<ServiceDetailPage> createState() => _ServiceDetailPageState();
}

class _ServiceDetailPageState extends State<ServiceDetailPage> {
  ServiceDetailModel? _data;
  Object? _error;
  var _loading = true;
  ServiceVariantDetailModel? _selectedVariant;

  static const double _heroHeight = 300;

  /// How far the rounded sheet overlaps the hero (smaller spacer → higher card).
  static const double _heroOverlap = 40;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.serviceId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Missing service id';
      });
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final d = await sl<ServiceCatalogRepository>().getService(widget.serviceId);
      if (!mounted) {
        return;
      }
      setState(() {
        _data = d;
        _loading = false;
        final variants = d.variants.where((v) => v.isActive).toList();
        if (variants.length == 1) {
          _selectedVariant = variants.first;
        } else if (variants.isNotEmpty) {
          final popular = variants.where((v) => v.isPopular).toList();
          _selectedVariant = popular.isNotEmpty ? popular.first : variants.first;
        }
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  String _priceRange(ServiceDetailModel s) {
    final fmt = NumberFormat.simpleCurrency(
      name: s.currency,
      decimalDigits: 0,
    );
    if (s.priceMin == s.priceMax) {
      return fmt.format(s.priceMin);
    }
    return '${fmt.format(s.priceMin)} – ${fmt.format(s.priceMax)}';
  }

  String _variantPrice(ServiceDetailModel s, ServiceVariantDetailModel v) {
    return NumberFormat.simpleCurrency(
      name: s.currency,
      decimalDigits: 0,
    ).format(v.price);
  }

  String _err(Object e) => e is Failure ? e.message : e.toString();

  bool _orgVerified(ServiceOrgDetailModel o) =>
      o.verificationStatus?.value == 'V';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark,
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        extendBody: true,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _err(_error!),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : _data == null
                    ? const SizedBox.shrink()
                    : _buildContent(context, cs, _data!),
        bottomNavigationBar: _loading || _error != null || _data == null
            ? null
            : _buildBottomBar(context, cs, _data!),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ColorScheme cs,
    ServiceDetailModel s,
  ) {
    final vt = VaxiilText.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final topPad = MediaQuery.of(context).padding.top;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: _heroHeight,
          child: _ServiceDetailHero(
            primaryImageUrl: s.primaryImage,
            cs: cs,
          ),
        ),
        CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: (_heroHeight - _heroOverlap).clamp(0.0, _heroHeight),
              ),
            ),
            SliverToBoxAdapter(
              child: Material(
                color: AppTheme.backgroundColor,
                elevation: 12,
                shadowColor: Colors.black.withOpacity(0.12),
                surfaceTintColor: Colors.transparent,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: ResponsiveContent(
                  narrowMaxWidth: 672,
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  _TitleAccentCard(
                    s: s,
                    vt: vt,
                    cs: cs,
                  ),
                  const SizedBox(height: 24),
                  if (s.variants.where((v) => v.isActive).length > 1) ...[
                    Text(
                      'Duration & investment',
                      style: vt.sectionTitle.copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: 12),
                    ...s.variants.where((v) => v.isActive).map(
                          (v) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _VariantPill(
                              selected: _selectedVariant?.id == v.id,
                              label: v.name.isNotEmpty
                                  ? v.name
                                  : '${v.durationMinutes} min',
                              price: _variantPrice(s, v),
                              popular: v.isPopular,
                              onTap: () =>
                                  setState(() => _selectedVariant = v),
                              cs: cs,
                            ),
                          ),
                        ),
                  ],
                  if (s.variants.where((v) => v.isActive).length == 1) ...[
                    Text(
                      'Duration & investment',
                      style: vt.sectionTitle.copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: 12),
                    _VariantPill(
                      selected: true,
                      label: s.variants.first.name.isNotEmpty
                          ? s.variants.first.name
                          : '${s.variants.first.durationMinutes} min',
                      price: _variantPrice(s, s.variants.first),
                      popular: s.variants.first.isPopular,
                      onTap: () {},
                      cs: cs,
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 16),
                  _ProviderAccentCard(
                    organization: s.organization,
                    verified: _orgVerified(s.organization),
                    cs: cs,
                    vt: vt,
                  ),
                  if (s.availabilityNotes != null &&
                      s.availabilityNotes!.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _ProTipCard(
                      text: s.availabilityNotes!.trim(),
                      cs: cs,
                    ),
                  ],
                  if (s.media.where((m) => m.fileUrl != null).length > 1) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Photos',
                      style: vt.sectionTitle.copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: s.media.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final m = s.media[i];
                          if (m.fileUrl == null) {
                            return const SizedBox.shrink();
                          }
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: m.fileUrl!,
                              width: 120,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  if (s.showLocationOnListing &&
                      (s.address.isNotEmpty || s.city.isNotEmpty)) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Location',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${s.address}, ${s.city} ${s.postalCode}, ${s.country}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ] else if (!s.showLocationOnListing) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Exact location is shared after you book.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ],
                  SizedBox(height: 100 + bottomInset),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: VaxiilSiteFooter()),
          ],
        ),
        Positioned(
          top: topPad + 8,
          left: 16,
          child: _FrostedIconButton(
            onPressed: () => context.pop(),
            child: HeroIcon(
              HeroIcons.arrowLeft,
              style: HeroIconStyle.outline,
              color: cs.primary,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }

  void _onBookPressed(BuildContext context, String serviceId) {
    final vq = _selectedVariant != null
        ? '&variantId=${_selectedVariant!.id}'
        : '';
    final bookPath = '${AppRoutes.serviceBooking}?id=$serviceId$vq';
    final auth = context.read<AuthCubit>().state;
    if (!auth.isAuthenticated) {
      context.push(AppRoutes.login);
      return;
    }
    if (auth.user?.isVerified != true) {
      final returnUrl = Uri.encodeComponent(bookPath);
      context.push(
        '${AppRoutes.identityVerification}?returnUrl=$returnUrl',
      );
      return;
    }
    context.push(bookPath);
  }

  Widget _buildBottomBar(
    BuildContext context,
    ColorScheme cs,
    ServiceDetailModel s,
  ) {
    final vt = VaxiilText.of(context);
    final variants = s.variants.where((v) => v.isActive).toList();
    final canBook = variants.length <= 1 || _selectedVariant != null;
    final displayPrice = variants.isEmpty
        ? _priceRange(s)
        : _selectedVariant != null
            ? _variantPrice(s, _selectedVariant!)
            : _priceRange(s);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface.withOpacity(0.92),
            border: Border(
              top: BorderSide(
                color: cs.outlineVariant.withOpacity(0.35),
              ),
            ),
          ),
          child: ResponsiveContent(
            narrowMaxWidth: 672,
            padding: EdgeInsets.fromLTRB(
              24,
              12,
              24,
              12 + MediaQuery.of(context).padding.bottom,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'SELECTED PRICE',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: cs.onSurfaceVariant,
                              fontSize: 10,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        displayPrice,
                        style: vt.pricePrimary.copyWith(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primaryContainer,
                    foregroundColor: cs.onPrimaryContainer,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    elevation: 4,
                    shadowColor: cs.primaryContainer.withOpacity(0.35),
                  ),
                  onPressed: !canBook
                      ? null
                      : () => _onBookPressed(context, s.id),
                  icon: HeroIcon(
                    HeroIcons.calendarDays,
                    style: HeroIconStyle.outline,
                    color: cs.onPrimaryContainer,
                    size: 22,
                  ),
                  label: const Text(
                    'Book now',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceDetailHero extends StatelessWidget {
  const _ServiceDetailHero({
    required this.primaryImageUrl,
    required this.cs,
  });

  final String? primaryImageUrl;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (primaryImageUrl != null)
          CachedNetworkImage(
            imageUrl: primaryImageUrl!,
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
                size: 48,
                color: cs.primary,
              ),
            ),
          )
        else
          ColoredBox(
            color: cs.surfaceContainerHigh,
            child: Icon(
              Icons.spa_outlined,
              size: 48,
              color: cs.primary,
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                AppTheme.backgroundColor,
                AppTheme.backgroundColor.withOpacity(0),
              ],
              stops: const [0.0, 0.45],
            ),
          ),
        ),
      ],
    );
  }
}

class _FrostedIconButton extends StatelessWidget {
  const _FrostedIconButton({
    required this.onPressed,
    required this.child,
  });

  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.white.withOpacity(0.82),
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _TitleAccentCard extends StatelessWidget {
  const _TitleAccentCard({
    required this.s,
    required this.vt,
    required this.cs,
  });

  final ServiceDetailModel s;
  final VaxiilText vt;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final categoryLabel = (s.subCategory.category.name.isNotEmpty
            ? s.subCategory.category.name
            : s.subCategory.name)
        .toUpperCase();
    final rating = s.ratingLabel;
    final features = s.featureMappings.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF141E17).withOpacity(0.08),
            offset: const Offset(0, 12),
            blurRadius: 32,
          ),
          BoxShadow(
            color: const Color(0xFF141E17).withOpacity(0.04),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoryLabel,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.name,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            color: cs.onSurface,
                          ),
                    ),
                  ],
                ),
              ),
              if (rating != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        rating,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            s.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.45,
                ),
          ),
          if (features.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                for (var i = 0; i < 3; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: i < 2 ? 8 : 0,
                      ),
                      child: i < features.length
                          ? _FeatureBentoCell(
                              mapping: features[i],
                              cs: cs,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatureBentoCell extends StatelessWidget {
  const _FeatureBentoCell({
    required this.mapping,
    required this.cs,
  });

  final ServiceFeatureMappingRowModel mapping;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final icon = heroIconFromDbName(
      mapping.feature.icon,
      fallback: HeroIcons.sparkles,
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HeroIcon(
            icon,
            style: HeroIconStyle.outline,
            color: cs.primary,
            size: 24,
          ),
          const SizedBox(height: 6),
          Text(
            mapping.feature.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                  fontSize: 11,
                ),
          ),
        ],
      ),
    );
  }
}

class _VariantPill extends StatelessWidget {
  const _VariantPill({
    required this.selected,
    required this.label,
    required this.price,
    required this.popular,
    required this.onTap,
    required this.cs,
  });

  final bool selected;
  final String label;
  final String price;
  final bool popular;
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? cs.surfaceContainerHigh : cs.surfaceContainer,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? cs.primary
                        : cs.primary.withOpacity(0.35),
                    width: 2,
                  ),
                  color: selected ? cs.primary : Colors.transparent,
                ),
                child: selected
                    ? Icon(
                        Icons.check,
                        size: 14,
                        color: cs.onPrimary,
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    if (popular) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cs.secondaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Popular',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: cs.onSecondaryContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                price,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderAccentCard extends StatelessWidget {
  const _ProviderAccentCard({
    required this.organization,
    required this.verified,
    required this.cs,
    required this.vt,
  });

  final ServiceOrgDetailModel organization;
  final bool verified;
  final ColorScheme cs;
  final VaxiilText vt;

  @override
  Widget build(BuildContext context) {
    final initial = organization.name.isNotEmpty
        ? organization.name[0].toUpperCase()
        : '?';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: cs.secondaryContainer,
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
              ),
              if (verified)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      Icons.verified,
                      size: 12,
                      color: cs.onPrimary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  organization.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  verified ? 'Verified provider' : 'Service provider',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (organization.verificationStatus != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    organization.verificationStatus!.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProTipCard extends StatelessWidget {
  const _ProTipCard({
    required this.text,
    required this.cs,
  });

  final String text;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.warningColor;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: accent, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: accent),
              const SizedBox(width: 8),
              Text(
                'Pro-tip for best results',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.45,
                ),
          ),
        ],
      ),
    );
  }
}
