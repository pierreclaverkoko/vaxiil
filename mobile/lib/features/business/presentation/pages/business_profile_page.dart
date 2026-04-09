import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/features/business/data/organization_models.dart';
import 'package:vaxiil_mobile/features/business/data/organization_repository.dart';
import 'package:vaxiil_mobile/features/business/presentation/widgets/business_profile_hub_widgets.dart';
import 'package:vaxiil_mobile/features/business/presentation/widgets/organization_analytics_summary.dart';
import 'package:vaxiil_mobile/features/business/presentation/widgets/organization_kyb_section.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';

/// KYB-driven hub layouts (Stitch): verified hub, pending review, or not sent.
enum _BusinessHubPhase {
  verified,
  kybPending,
  kybNotSent,
}

_BusinessHubPhase _hubPhase(OrganizationModel o) {
  if (o.isVerified) return _BusinessHubPhase.verified;
  final code = o.verificationStatus?.value ?? '';
  if (code == 'S') {
    return _BusinessHubPhase.kybNotSent;
  }
  final pendingReview = code == 'P' && o.kybSubmittedAt != null;
  if (pendingReview) return _BusinessHubPhase.kybPending;
  return _BusinessHubPhase.kybNotSent;
}

class BusinessProfilePage extends StatefulWidget {
  /// Creates the organization profile / hub screen.
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
    final topInset = MediaQuery.of(context).padding.top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: FutureBuilder<OrganizationModel>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              backgroundColor: AppTheme.backgroundColor,
              body: const Center(child: CircularProgressIndicator()),
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
          final phase = _hubPhase(o);
          return Scaffold(
            backgroundColor: AppTheme.backgroundColor,
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: AppTheme.backgroundColor.withOpacity(0.92),
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              foregroundColor: AppTheme.primaryVariant,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
              title: Text(
                phase == _BusinessHubPhase.verified
                    ? 'Company hub'
                    : 'Business hub',
              ),
              actions: [
                if (phase == _BusinessHubPhase.kybNotSent)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .errorContainer
                              .withOpacity(0.9),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'KYB NOT SENT',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer,
                                  ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            body: SafeArea(
              top: false,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  kToolbarHeight + topInset + 8,
                  20,
                  32,
                ),
                children: [
                  switch (phase) {
                    _BusinessHubPhase.verified => _VerifiedHubBody(
                        organization: o,
                        onReload: _reloadOrganization,
                      ),
                    _BusinessHubPhase.kybPending => _KybPendingHubBody(
                        organization: o,
                        onReload: _reloadOrganization,
                      ),
                    _BusinessHubPhase.kybNotSent => _KybNotSentHubBody(
                        organization: o,
                        onReload: _reloadOrganization,
                      ),
                  },
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VerifiedHubBody extends StatelessWidget {
  const _VerifiedHubBody({
    required this.organization,
    required this.onReload,
  });

  final OrganizationModel organization;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VerifiedCompanyHero(org: organization),
        const SizedBox(height: 20),
        VerifiedHubQuickActions(organizationId: organization.id),
        const SizedBox(height: 28),
        FutureBuilder<OrganizationAnalyticsModel>(
          future: sl<OrganizationRepository>().analytics(organization.id),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              final msg = snap.error is Failure
                  ? (snap.error! as Failure).message
                  : snap.error.toString();
              return Text(msg);
            }
            return OrganizationAnalyticsSummary(
              organizationId: organization.id,
              analytics: snap.data!,
              heading: 'Insights',
              showLiveBadge: true,
            );
          },
        ),
        const SizedBox(height: 16),
        OrganizationKybSection(
          organization: organization,
          onSubmitted: onReload,
        ),
      ],
    );
  }
}

class _KybPendingHubBody extends StatelessWidget {
  const _KybPendingHubBody({
    required this.organization,
    required this.onReload,
  });

  final OrganizationModel organization;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const KybPendingBanner(),
        const SizedBox(height: 16),
        BusinessInfoReadOnlyCard(org: organization),
        const SizedBox(height: 16),
        OrganizationKybSection(
          organization: organization,
          onSubmitted: onReload,
        ),
        const SizedBox(height: 24),
        const LockedManagementGrid(),
      ],
    );
  }
}

class _KybNotSentHubBody extends StatelessWidget {
  const _KybNotSentHubBody({
    required this.organization,
    required this.onReload,
  });

  final OrganizationModel organization;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const KybNotSentHero(),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Upload documents in the KYB section below.',
                ),
              ),
            );
          },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFB8C00),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          child: const Text('Complete verification'),
        ),
        const SizedBox(height: 24),
        BusinessInfoReadOnlyCard(org: organization),
        const SizedBox(height: 16),
        OrganizationKybSection(
          organization: organization,
          onSubmitted: onReload,
        ),
        const SizedBox(height: 24),
        const LockedManagementGrid(),
      ],
    );
  }
}
