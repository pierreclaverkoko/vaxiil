import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:intl/intl.dart';
import 'package:vaxiil_mobile/core/constants/app_constants.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/core/storage/secure_storage_service.dart';
import 'package:vaxiil_mobile/core/utils/hero_icon_from_name.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vaxiil_mobile/features/business/data/organization_models.dart';
import 'package:vaxiil_mobile/features/business/data/organization_repository.dart';
import 'package:vaxiil_mobile/features/services/data/service_catalog_models.dart';
import 'package:vaxiil_mobile/features/services/data/service_catalog_repository.dart';
import 'package:vaxiil_mobile/features/services/presentation/widgets/services_horizontal_card.dart';
import 'package:vaxiil_mobile/l10n/app_localizations.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/themes/vaxiil_text.dart';
import 'package:vaxiil_mobile/shared/utils/responsive.dart';
import 'package:vaxiil_mobile/shared/widgets/discovery_service_card.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_site_footer.dart';

class _CatalogData {
  const _CatalogData({
    required this.categories,
    required this.featured,
    required this.favorites,
    required this.nearby,
    required this.feed,
  });

  final List<ServiceCategoryModel> categories;
  final List<ServiceListItemModel> featured;
  final List<ServiceListItemModel> favorites;
  final List<ServiceListItemModel> nearby;
  final List<ServiceListItemModel> feed;
}

/// Discovery-style services hub: search, filters, category row (All first),
/// horizontal Featured / Favorites / Nearby, then home-style vertical feed.
class ServicesPage extends StatefulWidget {
  const ServicesPage({
    super.key,
    this.initialSearchQuery,
    this.initialCategoryId,
  });

  final String? initialSearchQuery;
  final String? initialCategoryId;

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _browseKey = GlobalKey();
  final _storage = SecureStorageService();

  String? _categoryId;
  String? _subCategoryId;
  String? _countryId;
  List<CountryBriefModel> _countries = [];
  _CatalogData? _data;
  bool _loading = true;
  Object? _error;
  Set<String> _favoriteIds = {};

  @override
  void initState() {
    super.initState();
    final q = widget.initialSearchQuery?.trim();
    if (q != null && q.isNotEmpty) {
      _searchController.text = q;
    }
    if (widget.initialCategoryId != null &&
        widget.initialCategoryId!.isNotEmpty) {
      _categoryId = widget.initialCategoryId;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _countryId = context.read<AuthCubit>().state.user?.defaultCountryId;
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    await Future.wait([_loadFavoriteIds(), _loadCountries()]);
    await _load();
  }

  Future<void> _loadCountries() async {
    try {
      final countries = await sl<OrganizationRepository>().listCountries();
      if (!mounted) return;
      setState(() => _countries = countries);
    } catch (_) {}
  }

  Future<void> _loadFavoriteIds() async {
    try {
      final raw =
          await _storage.readList(AppConstants.favoriteServiceIdsStorageKey);
      if (raw == null || !mounted) {
        return;
      }
      setState(() {
        _favoriteIds = raw.map((e) => e.toString()).toSet();
      });
    } catch (_) {}
  }

  Future<void> _persistFavoriteIds() async {
    try {
      await _storage.writeList(
        AppConstants.favoriteServiceIdsStorageKey,
        _favoriteIds.toList(),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _searchParam() => _searchController.text.trim();

  Future<void> _load() async {
    setState(() {
      _error = null;
      if (_data == null) {
        _loading = true;
      }
    });
    try {
      final repo = sl<ServiceCatalogRepository>();
      final search = _searchParam();
      final cat = _categoryId;
      final sub = _subCategoryId;
      final country = _countryId;

      final categories = await repo.listCategories();
      final featured = await repo.listServices(
        featured: true,
        pageSize: 12,
        search: search.isEmpty ? null : search,
        categoryId: cat,
        subCategoryId: sub,
        countryId: country,
      );
      final feed = await repo.listServices(
        pageSize: 50,
        search: search.isEmpty ? null : search,
        categoryId: cat,
        subCategoryId: sub,
        countryId: country,
      );

      final featuredIds = featured.map((e) => e.id).toSet();
      final favorites = feed
          .where((s) => _favoriteIds.contains(s.id) || s.isFavorite)
          .take(12)
          .toList();
      var nearby = feed.where((s) => !featuredIds.contains(s.id)).take(12).toList();
      if (nearby.length < 4) {
        nearby = feed.take(12).toList();
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _data = _CatalogData(
          categories: categories,
          featured: featured,
          favorites: favorites,
          nearby: nearby,
          feed: feed,
        );
        _loading = false;
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

  void _setCategoryAndReload(String? id) {
    setState(() => _categoryId = id);
    _load();
  }

  void _setSubCategoryAndReload(String? id) {
    setState(() => _subCategoryId = id);
    _load();
  }

  Future<void> _toggleFavorite(String serviceId) async {
    setState(() {
      if (_favoriteIds.contains(serviceId)) {
        _favoriteIds.remove(serviceId);
      } else {
        _favoriteIds.add(serviceId);
      }
    });
    await _persistFavoriteIds();
    await _load();
  }

  bool _isFavorite(ServiceListItemModel s) =>
      _favoriteIds.contains(s.id) || s.isFavorite;

  String _formatPriceRange(ServiceListItemModel s) {
    final fmt = NumberFormat.simpleCurrency(decimalDigits: 0);
    if (s.priceMin == s.priceMax) {
      return fmt.format(s.priceMin);
    }
    return '${fmt.format(s.priceMin)} – ${fmt.format(s.priceMax)}';
  }

  String _errorMessage(Object error) {
    if (error is Failure) {
      return error.message;
    }
    return error.toString();
  }

  void _scrollToBrowse() {
    final ctx = _browseKey.currentContext;
    if (ctx == null) {
      return;
    }
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      alignment: 0.1,
    );
  }

  void _openFilters() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: cs.surfaceContainerLowest,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Filters',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Subcategory and advanced filters will use the same search '
                  'and category selection as the rest of this page.',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                if (_subCategoryId != null)
                  ListTile(
                    leading: HeroIcon(
                      HeroIcons.tag,
                      style: HeroIconStyle.outline,
                      color: cs.primary,
                    ),
                    title: const Text('Clear subcategory filter'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _setSubCategoryAndReload(null);
                    },
                  ),
                ListTile(
                  leading: HeroIcon(
                    HeroIcons.arrowPath,
                    style: HeroIconStyle.outline,
                    color: cs.primary,
                  ),
                  title: const Text('Reset search text'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _searchController.clear();
                    _load();
                  },
                ),
                ListTile(
                  leading: HeroIcon(
                    HeroIcons.squares2x2,
                    style: HeroIconStyle.outline,
                    color: cs.primary,
                  ),
                  title: const Text('Show all categories'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _setCategoryAndReload(null);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vt = VaxiilText.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark,
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: cs.surface,
      ),
      child: Scaffold(
        primary: false,
        backgroundColor: AppTheme.backgroundColor,
        appBar: context.isExpandedShell
            ? null
            : AppBar(
                title: Text(
                  'Services',
                  style: vt.sectionTitle.copyWith(fontSize: 20),
                ),
                backgroundColor: AppTheme.backgroundColor,
                surfaceTintColor: Colors.transparent,
              ),
        body: RefreshIndicator(
          color: cs.primary,
          onRefresh: _load,
          child: _buildBody(cs, vt),
        ),
      ),
    );
  }

  Widget _buildBody(ColorScheme cs, VaxiilText vt) {
    if (_loading && _data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _data == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            _errorMessage(_error!),
            style: TextStyle(color: cs.error),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _load,
            child: const Text('Retry'),
          ),
        ],
      );
    }

    final data = _data!;

    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
          sliver: SliverToBoxAdapter(
            child: ResponsiveContent(
              maxWidth: 1280,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                    controller: _searchController,
                    style: vt.body16OnSurface,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                      hintText: 'Search for wellness services',
                      hintStyle: vt.discoverySubtitle.copyWith(
                        color: cs.onSurfaceVariant.withOpacity(0.55),
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: cs.primary.withOpacity(0.65),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _load(),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: _openFilters,
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: Center(
                        child: HeroIcon(
                          HeroIcons.funnel,
                          style: HeroIconStyle.outline,
                          color: cs.primary,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: ResponsiveContent(
            maxWidth: 1280,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
              child: DropdownButtonFormField<String>(
                value: _countryId != null &&
                        _countries.any((c) => c.id == _countryId)
                    ? _countryId
                    : '',
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).countryFilterLabel,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  DropdownMenuItem<String>(
                    value: '',
                    child: Text(AppLocalizations.of(context).countryFilterAll),
                  ),
                  ..._countries.map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(c.name),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() =>
                      _countryId = (value == null || value.isEmpty) ? null : value);
                  _load();
                },
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: ResponsiveContent(
            maxWidth: 1280,
            child: SizedBox(
              height: 112,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _CategoryOrb(
                    label: 'All',
                    selected: _categoryId == null,
                    icon: HeroIcons.squares2x2,
                    onTap: () {
                      if (_categoryId != null) {
                        _setCategoryAndReload(null);
                      }
                    },
                  ),
                ),
                ...data.categories.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _CategoryOrb(
                      label: c.name,
                      selected: _categoryId == c.id,
                      icon: heroIconFromDbName(c.icon),
                      onTap: () => _setCategoryAndReload(c.id),
                    ),
                  ),
                ),
              ],
            ),
            ),
          ),
        ),
        _horizontalSection(
          title: 'Featured services',
          items: data.featured,
          emptyHint: 'No featured services for these filters.',
          onViewAll: _scrollToBrowse,
          cs: cs,
          vt: vt,
        ),
        _horizontalSection(
          title: 'Favorite services',
          items: data.favorites,
          emptyHint: 'Tap the heart on a card to save favorites here.',
          onViewAll: _scrollToBrowse,
          cs: cs,
          vt: vt,
        ),
        _horizontalSection(
          title: 'Nearby services',
          items: data.nearby,
          emptyHint: 'No services to show yet. Try another category.',
          onViewAll: _scrollToBrowse,
          cs: cs,
          vt: vt,
        ),
        SliverToBoxAdapter(
          child: ResponsiveContent(
            maxWidth: 1280,
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
            child: Row(
              key: _browseKey,
              children: [
                Expanded(
                  child: Text(
                    'Browse all services',
                    style: vt.sectionTitle.copyWith(fontSize: 22),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (data.feed.isEmpty)
          SliverToBoxAdapter(
            child: ResponsiveContent(
              maxWidth: 1280,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'No services match your filters.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
              ),
            ),
          )
        else
          SliverToBoxAdapter(
            child: ResponsiveContent(
              maxWidth: 1280,
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
              child: Column(
                children: [
                  for (var i = 0; i < data.feed.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: DiscoveryServiceCard(
                        item: data.feed[i],
                        priceMain: _formatPriceRange(data.feed[i]),
                        dark: i.isOdd,
                        onOpen: () => context.push(
                          '${AppRoutes.serviceDetails}?id=${data.feed[i].id}',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        const SliverToBoxAdapter(child: VaxiilSiteFooter()),
      ],
    );
  }

  Widget _horizontalSection({
    required String title,
    required List<ServiceListItemModel> items,
    required String emptyHint,
    required VoidCallback onViewAll,
    required ColorScheme cs,
    required VaxiilText vt,
  }) {
    return SliverToBoxAdapter(
      child: ResponsiveContent(
        maxWidth: 1280,
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: vt.sectionTitle.copyWith(fontSize: 22),
                  ),
                ),
                TextButton(
                  onPressed: onViewAll,
                  child: Text(
                    'VIEW ALL',
                    style: vt.viewAllLink.copyWith(
                      fontSize: 12,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Text(
                emptyHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              )
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppTheme.editorialShadow,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: SizedBox(
                    height: ServicesHorizontalCard.cardHeight,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final s = items[i];
                        return ServicesHorizontalCard(
                          item: s,
                          priceMain: _formatPriceRange(s),
                          isFavorite: _isFavorite(s),
                          onOpen: () => context.push(
                            '${AppRoutes.serviceDetails}?id=${s.id}',
                          ),
                          onFavoriteTap: () => _toggleFavorite(s.id),
                        );
                      },
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _CategoryOrb extends StatelessWidget {
  const _CategoryOrb({
    required this.label,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final HeroIcons icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = selected ? cs.primaryContainer : cs.surfaceContainerHighest;
    final fg = selected ? cs.onPrimaryContainer : cs.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bg,
              ),
              child: Center(
                child: HeroIcon(
                  icon,
                  style: HeroIconStyle.outline,
                  size: 28,
                  color: selected ? cs.primary : fg,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
