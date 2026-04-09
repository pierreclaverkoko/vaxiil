import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
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
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vaxiil_mobile/features/business/data/organization_models.dart';
import 'package:vaxiil_mobile/features/business/data/organization_repository.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/themes/vaxiil_text.dart';

typedef _OrgsAndSummary = ({
  List<OrganizationModel> orgs,
  OrganizationMineSummaryModel summary,
});

/// Stitch “My Companies”: bento grid, CTA, collective impact from backend.
class BusinessListPage extends StatefulWidget {
  /// Creates the business list screen.
  const BusinessListPage({super.key});

  @override
  State<BusinessListPage> createState() => _BusinessListPageState();
}

class _BusinessListPageState extends State<BusinessListPage> {
  late Future<_OrgsAndSummary> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final repo = sl<OrganizationRepository>();
    _future = () async {
      final orgs = await repo.listMine();
      final summary = await repo.mineSummary();
      return (orgs: orgs, summary: summary);
    }();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vt = VaxiilText.of(context);
    final topInset = MediaQuery.of(context).padding.top;
    final barHeight = topInset + 56;
    final user = context.watch<AuthCubit>().state.user;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark,
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: cs.surface,
      ),
      child: Scaffold(
        primary: false,
        backgroundColor: cs.surface,
        body: Stack(
          fit: StackFit.expand,
          children: [
            RefreshIndicator(
              color: cs.primary,
              onRefresh: () async {
                setState(_reload);
                await context.read<AuthCubit>().refreshProfile();
                await _future;
              },
              child: FutureBuilder<_OrgsAndSummary>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: barHeight + 48),
                        const Center(child: CircularProgressIndicator()),
                      ],
                    );
                  }
                  if (snapshot.hasError) {
                    final msg = snapshot.error is Failure
                        ? (snapshot.error! as Failure).message
                        : snapshot.error.toString();
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(24, barHeight + 24, 24, 120),
                      children: [
                        Text(
                          msg,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(color: cs.error),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => setState(_reload),
                          child: const Text('Retry'),
                        ),
                      ],
                    );
                  }
                  final data = snapshot.data!;
                  final orgs = data.orgs;
                  final summary = data.summary;
                  final nf = NumberFormat.decimalPattern();

                  return CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(24, barHeight + 8, 24, 0),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'My Companies',
                                style: vt.greeting.copyWith(height: 1.1),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Manage and monitor your registered business '
                                'entities.',
                                style: vt.discoverySubtitle.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 28),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _GrowPortfolioCard(
                                onRegister: () =>
                                    context.push(AppRoutes.businessSetup),
                              ),
                              const SizedBox(height: 20),
                              ...orgs.map(
                                (o) => Padding(
                                  padding: const EdgeInsets.only(bottom: 20),
                                  child: _CompanyCard(
                                    org: o,
                                    onManage: () => context.push(
                                      '${AppRoutes.businessProfile}?id=${o.id}',
                                    ),
                                  ),
                                ),
                              ),
                              _CollectiveImpactCard(
                                beneficiaryCount:
                                    summary.collectiveBeneficiaries,
                                beneficiaryLabel: nf.format(
                                  summary.collectiveBeneficiaries,
                                ),
                                organizationCount: summary.organizationCount,
                                onViewInsights: orgs.isEmpty
                                    ? null
                                    : () {
                                        final id = orgs.first.id;
                                        context.push(
                                          '${AppRoutes.businessAnalytics}'
                                          '?id=$id',
                                        );
                                      },
                              ),
                              if (orgs.isEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'No organization on file yet. Register a '
                                  'business to get started.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: AppTheme.textSecondary),
                                ),
                              ],
                              const SizedBox(height: 96),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _MyCompaniesTopBar(
                topPadding: topInset,
                avatarUrl: user?.avatarUrl,
                onSearch: () => context.go(AppRoutes.services),
                onProfile: () => context.go(AppRoutes.profile),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyCompaniesTopBar extends StatelessWidget {
  const _MyCompaniesTopBar({
    required this.topPadding,
    required this.onSearch,
    required this.onProfile,
    this.avatarUrl,
  });

  final double topPadding;
  final VoidCallback onSearch;
  final VoidCallback onProfile;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: topPadding,
            left: 24,
            right: 24,
            bottom: 12,
          ),
          decoration: AppTheme.frostedTopBarDecoration(cs),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: CachedNetworkImage(
                    imageUrl: AppConstants.brandLogoImageUrl,
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                    placeholder: (_, __) => const SizedBox(
                      height: 40,
                      width: 64,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Text(
                      'Vaxiil',
                      style: VaxiilText.of(context).frostedAppBarTitle,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: onSearch,
                icon: Icon(Icons.search, color: cs.primary, size: 26),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0x4DC8E6C9),
                  padding: const EdgeInsets.all(8),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onProfile,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: avatarUrl != null && avatarUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: avatarUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => ColoredBox(
                              color: cs.surfaceContainerHigh,
                              child: Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: cs.primary,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => ColoredBox(
                              color: cs.surfaceContainerHigh,
                              child: Icon(Icons.person, color: cs.primary),
                            ),
                          )
                        : ColoredBox(
                            color: cs.surfaceContainerHigh,
                            child: Icon(Icons.person, color: cs.primary),
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

class _GrowPortfolioCard extends StatelessWidget {
  const _GrowPortfolioCard({required this.onRegister});

  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(minHeight: 220),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: cs.secondaryContainer,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.editorialShadow,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -28,
              bottom: -28,
              child: Icon(
                Icons.spa_outlined,
                size: 160,
                color: cs.onSecondaryContainer.withOpacity(0.12),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Grow Your Portfolio',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onSecondaryContainer,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Register a new business entity under the Vaxiil ecosystem '
                  'to start tracking progress.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSecondaryContainer.withOpacity(0.85),
                        height: 1.45,
                      ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onRegister,
                  icon: const Icon(Icons.add_business, size: 22),
                  label: const Text('Register New Company'),
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompanyCard extends StatelessWidget {
  const _CompanyCard({
    required this.org,
    required this.onManage,
  });

  final OrganizationModel org;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final verified = org.isVerified;
    final pending = org.verificationStatus?.value == 'P';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onManage,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CompanyLogoTile(logoUrl: org.logoUrl),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (org.myMembershipRole != null)
                          _RoleChip(
                            label: org.myMembershipRole!.title,
                            filled: org.myMembershipRole!.value == 'O',
                          ),
                        const SizedBox(height: 6),
                        if (verified)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified,
                                size: 16,
                                color: cs.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Verified',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: cs.primary,
                                    ),
                              ),
                            ],
                          )
                        else if (pending)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 16,
                                color: cs.outline,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Pending',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: cs.outline,
                                    ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  org.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  (org.description != null &&
                          org.description!.trim().isNotEmpty)
                      ? org.description!.trim()
                      : (org.typeDisplayName ?? org.email),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.groups_2_outlined,
                      size: 22,
                      color: cs.onSurfaceVariant.withOpacity(0.7),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Team & services',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                      ),
                    ),
                    TextButton(
                      onPressed: onManage,
                      style: TextButton.styleFrom(
                        foregroundColor: cs.primary,
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Manage'),
                          const SizedBox(width: 4),
                          HeroIcon(
                            HeroIcons.arrowRight,
                            style: HeroIconStyle.outline,
                            size: 14,
                            color: cs.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompanyLogoTile extends StatelessWidget {
  const _CompanyLogoTile({this.logoUrl});

  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final u = logoUrl?.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 64,
        height: 64,
        color: cs.surfaceContainerHigh,
        child: u != null && u.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: u,
                fit: BoxFit.cover,
                placeholder: (_, __) => Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.primary,
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Icon(
                  Icons.business,
                  color: cs.primary,
                  size: 32,
                ),
              )
            : Icon(
                Icons.business,
                color: cs.primary,
                size: 32,
              ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label, required this.filled});

  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? cs.secondaryContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: filled ? cs.onSecondaryContainer : cs.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _CollectiveImpactCard extends StatelessWidget {
  const _CollectiveImpactCard({
    required this.beneficiaryCount,
    required this.beneficiaryLabel,
    required this.organizationCount,
    this.onViewInsights,
  });

  final int beneficiaryCount;
  final String beneficiaryLabel;
  final int organizationCount;
  final VoidCallback? onViewInsights;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final orgWord = organizationCount == 1 ? 'business' : 'businesses';

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary,
            cs.primaryContainer,
          ],
        ),
        boxShadow: AppTheme.editorialShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'QUARTERLY INSIGHT',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: cs.onPrimary.withOpacity(0.95),
                  ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Your collective impact has reached $beneficiaryLabel '
            'beneficiaries.',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.onPrimary,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            beneficiaryCount == 0
                ? 'Completed appointments across your organizations will '
                    'appear here as you grow your impact.'
                : 'Aggregate completed appointments across all '
                    '$organizationCount $orgWord you manage.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onPrimary.withOpacity(0.88),
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onViewInsights,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFA3F69C),
                    foregroundColor: const Color(0xFF002204),
                    disabledBackgroundColor:
                        const Color(0xFFA3F69C).withOpacity(0.5),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text('View Consolidated Insights'),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.auto_graph,
                  size: 40,
                  color: cs.onPrimary.withOpacity(0.45),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
