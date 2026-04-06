import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vaxiil_mobile/features/business/data/organization_models.dart';
import 'package:vaxiil_mobile/features/business/data/organization_repository.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/widgets/org_logo_avatar.dart';
import 'package:vaxiil_mobile/shared/widgets/soft_card.dart';

class BusinessListPage extends StatefulWidget {
  const BusinessListPage({super.key});

  @override
  State<BusinessListPage> createState() => _BusinessListPageState();
}

class _BusinessListPageState extends State<BusinessListPage> {
  late Future<List<OrganizationModel>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = sl<OrganizationRepository>().listMine();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      primary: false,
      appBar: AppBar(
        title: const Text('Your businesses'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(_reload);
          await context.read<AuthCubit>().refreshProfile();
          await _future;
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FilledButton.tonalIcon(
              onPressed: () => context.push(AppRoutes.businessSetup),
              icon: HeroIcon(
                HeroIcons.plusCircle,
                style: HeroIconStyle.outline,
                color: cs.primary,
              ),
              label: const Text('Register a business'),
              style: FilledButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
              child: Text(
                'Create an organization profile',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<OrganizationModel>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  final msg = snapshot.error is Failure
                      ? (snapshot.error! as Failure).message
                      : snapshot.error.toString();
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(msg),
                  );
                }
                final orgs = snapshot.data ?? [];
                if (orgs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No organization on file yet. '
                      'Register a business to get started.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: orgs.map((o) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SoftCard(
                        child: ListTile(
                          leading: OrgLogoAvatar(logoUrl: o.logoUrl),
                          title: Text(o.name),
                          subtitle: Text(
                            o.typeDisplayName ?? o.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const HeroIcon(
                            HeroIcons.chevronRight,
                            style: HeroIconStyle.outline,
                            color: AppTheme.textSecondary,
                          ),
                          onTap: () => context.push(
                            '${AppRoutes.businessProfile}?id=${o.id}',
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
