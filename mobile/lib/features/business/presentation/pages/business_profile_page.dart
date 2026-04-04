import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/features/business/data/organization_models.dart';
import 'package:vaxiil_mobile/features/business/data/organization_repository.dart';
import 'package:vaxiil_mobile/features/business/presentation/widgets/organization_kyb_section.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/widgets/soft_card.dart';
import 'package:vaxiil_mobile/shared/widgets/soft_list_divider.dart';

class BusinessProfilePage extends StatefulWidget {
  const BusinessProfilePage({super.key, this.organizationId});

  final String? organizationId;

  @override
  State<BusinessProfilePage> createState() => _BusinessProfilePageState();
}

class _BusinessProfilePageState extends State<BusinessProfilePage> {
  late Future<OrganizationModel> _future;

  @override
  void initState() {
    super.initState();
    _loadFuture();
  }

  void _loadFuture() {
    final id = widget.organizationId;
    if (id == null || id.isEmpty) {
      _future = Future<OrganizationModel>.error(
        NetworkFailure.badRequest(message: 'Missing organization id'),
      );
    } else {
      _future = sl<OrganizationRepository>().getById(id);
    }
  }

  void _reloadOrganization() {
    setState(_loadFuture);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business profile'),
      ),
      body: FutureBuilder<OrganizationModel>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final msg = snapshot.error is Failure
                ? (snapshot.error! as Failure).message
                : snapshot.error.toString();
            return Center(child: Text(msg));
          }
          final o = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        HeroIcon(
                          HeroIcons.buildingOffice2,
                          style: HeroIconStyle.outline,
                          color: AppTheme.primaryVariant,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            o.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      o.typeDisplayName ?? '',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(o.email, style: Theme.of(context).textTheme.bodyMedium),
                    if (o.phone != null && o.phone!.isNotEmpty)
                      Text(o.phone!, style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    Text(
                      '${o.address}, ${o.city} ${o.postalCode}, ${o.country}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              OrganizationKybSection(
                organization: o,
                onSubmitted: _reloadOrganization,
              ),
              const SizedBox(height: 12),
              SoftCard(
                child: Column(
                  children: [
                    ListTile(
                      leading: HeroIcon(
                        HeroIcons.userGroup,
                        style: HeroIconStyle.outline,
                        color: AppTheme.primaryVariant,
                      ),
                      title: const Text('Team & practitioners'),
                      subtitle: const Text(
                        'Members linked to this organization',
                      ),
                      trailing: HeroIcon(
                        HeroIcons.chevronRight,
                        style: HeroIconStyle.outline,
                        color: AppTheme.textSecondary,
                      ),
                      onTap: () => context.push(
                        '${AppRoutes.businessPractitioners}?id=${o.id}',
                      ),
                    ),
                    const SoftListDivider(),
                    ListTile(
                      leading: HeroIcon(
                        HeroIcons.chartBar,
                        style: HeroIconStyle.outline,
                        color: AppTheme.primaryVariant,
                      ),
                      title: const Text('Analytics'),
                      subtitle: const Text('Summary metrics (booking layer pending)'),
                      trailing: HeroIcon(
                        HeroIcons.chevronRight,
                        style: HeroIconStyle.outline,
                        color: AppTheme.textSecondary,
                      ),
                      onTap: () => context.push(
                        '${AppRoutes.businessAnalytics}?id=${o.id}',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
