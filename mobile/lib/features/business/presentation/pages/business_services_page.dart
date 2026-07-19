import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:intl/intl.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/features/business/data/provider_services_repository.dart';
import 'package:vaxiil_mobile/features/business/presentation/pages/business_service_edit_page.dart';
import 'package:vaxiil_mobile/features/services/data/service_catalog_models.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/utils/responsive.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_site_footer.dart';

/// Lists services for a verified organization; create/edit via [BusinessServiceEditPage].
class BusinessServicesPage extends StatefulWidget {
  const BusinessServicesPage({required this.organizationId, super.key});

  final String organizationId;

  @override
  State<BusinessServicesPage> createState() => _BusinessServicesPageState();
}

class _BusinessServicesPageState extends State<BusinessServicesPage> {
  List<ServiceListItemModel>? _items;
  Object? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.organizationId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Missing organization id';
      });
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final list = await sl<ProviderServicesRepository>().listServices(
        widget.organizationId,
      );
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  String _fmt(ServiceListItemModel s) {
    final fmt = NumberFormat.simpleCurrency(decimalDigits: 0);
    if (s.priceMin == s.priceMax) {
      return fmt.format(s.priceMin);
    }
    return '${fmt.format(s.priceMin)} – ${fmt.format(s.priceMax)}';
  }

  String _err(Object e) => e is Failure ? e.message : e.toString();

  Widget _serviceCard(ServiceListItemModel s) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const HeroIcon(
          HeroIcons.sparkles,
          style: HeroIconStyle.outline,
          color: AppTheme.primaryVariant,
        ),
        title: Text(s.name),
        subtitle: Text(
          '${s.subCategory.name} · ${_fmt(s)}',
        ),
        trailing: const HeroIcon(
          HeroIcons.chevronRight,
          style: HeroIconStyle.outline,
        ),
        onTap: () async {
          await context.push(
            '${AppRoutes.businessServiceEdit}?id=${widget.organizationId}&serviceId=${s.id}',
          );
          if (mounted) _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Services')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push(
            '${AppRoutes.businessServiceEdit}?id=${widget.organizationId}',
          );
          if (mounted) _load();
        },
        child: const Icon(Icons.add),
      ),
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
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      if (_items == null || _items!.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: ResponsiveContent(
                            maxWidth: 1280,
                            child: const Center(
                              child: Text(
                                'No services yet. Tap + to add one.',
                              ),
                            ),
                          ),
                        )
                      else
                        SliverToBoxAdapter(
                          child: ResponsiveContent(
                            maxWidth: 1280,
                            padding: const EdgeInsets.all(16),
                            child: context.isMdUp
                                ? GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 2.8,
                                    ),
                                    itemCount: _items!.length,
                                    itemBuilder: (context, i) =>
                                        _serviceCard(_items![i]),
                                  )
                                : Column(
                                    children: [
                                      for (final s in _items!)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 12),
                                          child: _serviceCard(s),
                                        ),
                                    ],
                                  ),
                          ),
                        ),
                      const SliverToBoxAdapter(child: VaxiilSiteFooter()),
                    ],
                  ),
                ),
    );
  }
}
