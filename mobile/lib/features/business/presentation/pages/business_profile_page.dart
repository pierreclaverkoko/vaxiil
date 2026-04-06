import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/features/business/data/organization_models.dart';
import 'package:vaxiil_mobile/features/business/data/organization_repository.dart';
import 'package:vaxiil_mobile/features/business/presentation/widgets/business_verified_actions_grid.dart';
import 'package:vaxiil_mobile/features/business/presentation/widgets/organization_analytics_summary.dart';
import 'package:vaxiil_mobile/features/business/presentation/widgets/organization_kyb_section.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/widgets/org_logo_avatar.dart';
import 'package:vaxiil_mobile/shared/widgets/soft_card.dart';

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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: FutureBuilder<OrganizationModel>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              body: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: const BoxDecoration(
                  gradient: AppTheme.businessProfileGradient,
                ),
                child: const Center(child: CircularProgressIndicator()),
              ),
            );
          }
          if (snapshot.hasError) {
            final msg = snapshot.error is Failure
                ? (snapshot.error! as Failure).message
                : snapshot.error.toString();
            return Scaffold(
              appBar: AppBar(title: const Text('Business profile')),
              body: Center(child: Text(msg)),
            );
          }
          final o = snapshot.data!;
          return Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: AppTheme.primaryVariant,
              surfaceTintColor: Colors.transparent,
              title: const Text('Business profile'),
            ),
            body: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: AppTheme.businessProfileGradient,
              ),
              child: SafeArea(
                top: false,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    kToolbarHeight + MediaQuery.of(context).padding.top + 8,
                    16,
                    24,
                  ),
                  children: [
                    SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              OrgLogoAvatar(logoUrl: o.logoUrl, size: 56),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            o.name,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge,
                                          ),
                                        ),
                                        if (o.isVerified) ...[
                                          Container(
                                            width: 8,
                                            height: 8,
                                            margin:
                                                const EdgeInsets.only(right: 6),
                                            decoration: const BoxDecoration(
                                              color: AppTheme.successColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          Text(
                                            'Verified',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelMedium
                                                ?.copyWith(
                                                  color: AppTheme.primaryVariant,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      o.typeDisplayName ?? '',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppTheme.textSecondary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            o.email,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (o.phone != null && o.phone!.isNotEmpty)
                            Text(
                              o.phone!,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
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
                    if (o.isVerified) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Manage',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              shadows: const [
                                Shadow(
                                  blurRadius: 8,
                                  color: Color(0x33000000),
                                ),
                              ],
                            ),
                      ),
                      const SizedBox(height: 8),
                      BusinessVerifiedActionsGrid(organizationId: o.id),
                      const SizedBox(height: 8),
                      FutureBuilder<OrganizationAnalyticsModel>(
                        future: sl<OrganizationRepository>().analytics(o.id),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const SoftCard(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            );
                          }
                          if (snap.hasError) {
                            final msg = snap.error is Failure
                                ? (snap.error! as Failure).message
                                : snap.error.toString();
                            return SoftCard(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(msg),
                              ),
                            );
                          }
                          return OrganizationAnalyticsSummary(
                            organizationId: o.id,
                            analytics: snap.data!,
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
