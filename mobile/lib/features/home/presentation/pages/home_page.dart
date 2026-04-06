import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:intl/intl.dart';
import 'package:vaxiil_mobile/core/biometric/biometric_service.dart';
import 'package:vaxiil_mobile/core/constants/app_constants.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/core/storage/secure_storage_service.dart';
import 'package:vaxiil_mobile/core/utils/hero_icon_from_name.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vaxiil_mobile/features/services/data/service_catalog_models.dart';
import 'package:vaxiil_mobile/features/services/data/service_catalog_repository.dart';
import 'package:vaxiil_mobile/shared/themes/vaxiil_text.dart';
import 'package:vaxiil_mobile/shared/widgets/discovery_service_card.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_app_drawer.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_frosted_top_bar.dart';

/// Discovery home: logo bar, search, Daily Rituals + category chips, alternating
/// service cards with infinite scroll (Stitch “Home Discovery with Logo”).
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static var _biometricGateDone = false;

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<ServiceCategoryModel> _categories = [];
  final List<ServiceListItemModel> _feed = [];
  String? _selectedCategoryId;
  int _page = 1;
  bool _hasMore = true;
  bool _loadingInitial = true;
  bool _loadingMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeBiometricUnlock();
      _load();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loadingInitial) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 280) {
      _loadMore();
    }
  }

  Future<void> _maybeBiometricUnlock() async {
    if (_biometricGateDone) return;
    final storage = SecureStorageService();
    if (!await storage.isBiometricEnabled()) {
      _biometricGateDone = true;
      return;
    }
    final bio = BiometricService();
    if (!await bio.canAuthenticate) {
      _biometricGateDone = true;
      return;
    }
    _biometricGateDone = true;
    final ok = await bio.authenticate();
    if (!mounted) return;
    if (!ok) await context.read<AuthCubit>().logout();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      if (_categories.isEmpty) {
        _loadingInitial = true;
      }
    });
    try {
      final catalog = sl<ServiceCatalogRepository>();
      final categories = await catalog.listCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
      });
      await _loadFeed(reset: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loadingInitial = false;
      });
    }
  }

  Future<void> _loadFeed({required bool reset}) async {
    if (reset) {
      if (!mounted) return;
      setState(() {
        _error = null;
        _feed.clear();
        _page = 1;
        _hasMore = true;
        _loadingInitial = true;
      });
    } else {
      if (!_hasMore || _loadingMore) return;
      setState(() => _loadingMore = true);
    }
    try {
      final catalog = sl<ServiceCatalogRepository>();
      final nextPage = reset ? 1 : _page + 1;
      final q = _searchController.text.trim();
      final res = await catalog.listServicesPage(
        search: q.isEmpty ? null : q,
        categoryId: _selectedCategoryId,
        page: nextPage,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _feed
            ..clear()
            ..addAll(res.items);
        } else {
          _feed.addAll(res.items);
        }
        _page = nextPage;
        _hasMore = res.hasMore;
        _loadingInitial = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loadingInitial = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    await _loadFeed(reset: false);
  }

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

  void _openServices({String? search, String? categoryId}) {
    if (search != null && search.trim().isNotEmpty) {
      context.go(AppRoutes.services, extra: {'search': search.trim()});
      return;
    }
    if (categoryId != null) {
      context.go(AppRoutes.services, extra: {'categoryId': categoryId});
      return;
    }
    context.go(AppRoutes.services);
  }

  Future<void> _onCategorySelected(String? id) async {
    setState(() => _selectedCategoryId = id);
    await _loadFeed(reset: true);
  }

  Future<void> _onSearchSubmitted(String _) async {
    await _loadFeed(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().state.user;
    final cs = Theme.of(context).colorScheme;
    final vt = VaxiilText.of(context);
    final topInset = MediaQuery.of(context).padding.top;
    final barHeight = topInset + 56;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark,
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: cs.surface,
      ),
      child: Scaffold(
        key: _scaffoldKey,
        primary: false,
        backgroundColor: cs.surface,
        drawer: const VaxiilAppDrawer(),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: RefreshIndicator(
                color: cs.primary,
                onRefresh: _load,
                child: _loadingInitial && _feed.isEmpty && _error == null
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: barHeight + 48),
                        const Center(child: CircularProgressIndicator()),
                      ],
                    )
                  : _error != null && _feed.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            24,
                            barHeight + 24,
                            24,
                            24,
                          ),
                          children: [
                            Text(
                              _errorMessage(_error!),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(color: cs.error),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _load,
                              child: const Text('Retry'),
                            ),
                          ],
                        )
                      : CustomScrollView(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  24,
                                  barHeight + 8,
                                  24,
                                  0,
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  style: vt.body16OnSurface,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: cs.surfaceContainerHighest,
                                    hintText:
                                        'Search for wellness, yoga, or forest baths...',
                                    hintStyle: vt.discoverySubtitle.copyWith(
                                      color:
                                          cs.onSurfaceVariant.withOpacity(0.5),
                                    ),
                                    prefixIcon: Icon(
                                      Icons.search,
                                      color: cs.primary.withOpacity(0.6),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 16,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(999),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: _onSearchSubmitted,
                                ),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  28,
                                  24,
                                  0,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'CURATION',
                                          style: vt.discoverySubtitle.copyWith(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 2,
                                            color: cs.secondary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Daily Rituals',
                                          style: vt.sectionTitle.copyWith(
                                            fontSize: 28,
                                            color: cs.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                    TextButton(
                                      onPressed: _openServices,
                                      child: Text(
                                        'View all',
                                        style: vt.viewAllLink,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_categories.isNotEmpty)
                              SliverToBoxAdapter(
                                child: SizedBox(
                                  height: 64,
                                  child: ListView(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      16,
                                      20,
                                      8,
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        child: _DailyRitualChip(
                                          label: 'All',
                                          icon: HeroIcons.squares2x2,
                                          selected: _selectedCategoryId == null,
                                          onTap: () =>
                                              _onCategorySelected(null),
                                        ),
                                      ),
                                      ..._categories.map(
                                        (c) => Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          child: _DailyRitualChip(
                                            label: c.name,
                                            icon: heroIconFromDbName(c.icon),
                                            selected:
                                                _selectedCategoryId == c.id,
                                            onTap: () =>
                                                _onCategorySelected(c.id),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (_feed.isEmpty && !_loadingInitial)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    24,
                                    24,
                                    24,
                                    barHeight,
                                  ),
                                  child: Text(
                                    'No services match your filters yet.',
                                    style: vt.discoverySubtitle,
                                  ),
                                ),
                              ),
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, i) {
                                    final s = _feed[i];
                                    final dark = i.isOdd;
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 20,
                                      ),
                                      child: DiscoveryServiceCard(
                                        item: s,
                                        priceMain: _formatPriceRange(s),
                                        dark: dark,
                                        onOpen: () => context.push(
                                          '${AppRoutes.serviceDetails}?id=${s.id}',
                                        ),
                                      ),
                                    );
                                  },
                                  childCount: _feed.length,
                                ),
                              ),
                            ),
                            if (_loadingMore)
                              const SliverToBoxAdapter(
                                child: Padding(
                                  padding: EdgeInsets.only(bottom: 24),
                                  child: Center(
                                    child: SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: VaxiilFrostedTopBar(
                topPadding: topInset,
                logoUrl: AppConstants.brandLogoImageUrl,
                onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                onAvatarTap: () => context.go(AppRoutes.profile),
                avatarUrl: user?.avatarUrl,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyRitualChip extends StatelessWidget {
  const _DailyRitualChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final HeroIcons icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vt = VaxiilText.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFF1B5E20), Color(0xFF00450D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: selected ? null : cs.surfaceContainerHighest,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF141E17).withOpacity(0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HeroIcon(
                icon,
                style: HeroIconStyle.outline,
                size: 22,
                color: selected ? Colors.white : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: vt.categoryLabel.copyWith(
                  color: selected ? Colors.white : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
