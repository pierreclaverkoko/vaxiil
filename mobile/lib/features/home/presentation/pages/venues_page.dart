import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vaxiil_mobile/core/country/country_scope_service.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vaxiil_mobile/features/business/data/organization_models.dart';
import 'package:vaxiil_mobile/features/business/data/organization_repository.dart';
import 'package:vaxiil_mobile/l10n/app_localizations.dart';
import 'package:vaxiil_mobile/shared/widgets/country_scope_picker.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_site_footer.dart';

/// Full country-scoped trusted venues list (discover "View all").
class VenuesPage extends StatefulWidget {
  const VenuesPage({super.key});

  @override
  State<VenuesPage> createState() => _VenuesPageState();
}

class _VenuesPageState extends State<VenuesPage> {
  final _scope = sl<CountryScopeService>();
  List<CountryBriefModel> _countries = [];
  final List<OrganizationDiscoveryModel> _venues = [];
  int _page = 1;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profileDefault =
          context.read<AuthCubit>().state.user?.defaultCountryId;
      final countries = await sl<OrganizationRepository>().listCountries();
      await _scope.ensureInitialized(
        countries: countries,
        profileDefaultCountryId: profileDefault,
      );
      if (!mounted) return;
      setState(() => _countries = countries);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reload() async {
    final result = await sl<OrganizationRepository>().listDiscovery(
      countryId: _scope.countryId,
      page: 1,
      pageSize: 20,
    );
    if (!mounted) return;
    setState(() {
      _venues
        ..clear()
        ..addAll(result.items);
      _page = 1;
      _hasMore = result.hasMore;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final result = await sl<OrganizationRepository>().listDiscovery(
        countryId: _scope.countryId,
        page: next,
        pageSize: 20,
      );
      if (!mounted) return;
      setState(() {
        _venues.addAll(result.items);
        _page = next;
        _hasMore = result.hasMore;
      });
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _onCountryChanged(CountryBriefModel country) async {
    await _scope.setCountry(country);
    if (!mounted) return;
    setState(() {});
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.venuesTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ResponsiveContent(
        maxWidth: 1280,
        child: _loading
            ? Center(child: Text(l10n.venuesLoading))
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$_error', style: TextStyle(color: cs.error)),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _bootstrap,
                          child: Text(l10n.notificationsRetry),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _reload,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      children: [
                        Text(
                          l10n.venuesSubtitle,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: CountryScopePicker(
                            countries: _countries,
                            valueId: _scope.countryId,
                            onChanged: _onCountryChanged,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_venues.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: Text(l10n.venuesEmpty),
                          )
                        else
                          ..._venues.map(
                            (v) => Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: v.logoUrl != null
                                      ? NetworkImage(v.logoUrl!)
                                      : null,
                                  child: v.logoUrl == null
                                      ? Text(
                                          v.name.isNotEmpty
                                              ? v.name[0].toUpperCase()
                                              : '?',
                                        )
                                      : null,
                                ),
                                title: Text(v.name),
                                subtitle: Text(
                                  [
                                    if (v.city.isNotEmpty) v.city,
                                    if (v.description.isNotEmpty) v.description,
                                  ].join('\n'),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                isThreeLine: true,
                              ),
                            ),
                          ),
                        if (_hasMore)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Center(
                              child: OutlinedButton(
                                onPressed: _loadingMore ? null : _loadMore,
                                child: Text(
                                  _loadingMore
                                      ? l10n.venuesLoading
                                      : l10n.venuesLoadMore,
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
