import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:vaxiil_mobile/core/constants/app_constants.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_state.dart';
import 'package:vaxiil_mobile/shared/widgets/soft_card.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_logo.dart';

/// App information, version, and links to legal documents.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const String _description =
      'Vaxiil is a SaaS wellness platform for booking massage, therapy, '
      'and space rentals—with privacy-focused features and multi-tenant '
      'business tools.';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: HeroIcon(
            HeroIcons.arrowLeft,
            style: HeroIconStyle.outline,
            color: cs.onSurface,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              final authed = context.read<AuthCubit>().state.status ==
                  AuthStatus.authenticated;
              context.go(authed ? AppRoutes.home : AppRoutes.login);
            }
          },
        ),
        title: const Text('About'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: const VaxiilLogo(
              height: 100,
              width: 100,
              platePadding: EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            AppConstants.appName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            _description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final version = snapshot.hasData
                  ? '${snapshot.data!.version} (${snapshot.data!.buildNumber})'
                  : '…';
              return SoftCard(
                child: ListTile(
                  leading: HeroIcon(
                    HeroIcons.informationCircle,
                    style: HeroIconStyle.outline,
                    color: cs.primary,
                  ),
                  title: const Text('Version'),
                  subtitle: Text(version),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          SoftCard(
            child: Column(
              children: [
                ListTile(
                  leading: HeroIcon(
                    HeroIcons.documentText,
                    style: HeroIconStyle.outline,
                    color: cs.primary,
                  ),
                  title: const Text('Terms of service'),
                  trailing: HeroIcon(
                    HeroIcons.chevronRight,
                    style: HeroIconStyle.outline,
                    size: 20,
                    color: cs.outline,
                  ),
                  onTap: () => context.push(AppRoutes.terms),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: HeroIcon(
                    HeroIcons.shieldCheck,
                    style: HeroIconStyle.outline,
                    color: cs.primary,
                  ),
                  title: const Text('Privacy policy'),
                  trailing: HeroIcon(
                    HeroIcons.chevronRight,
                    style: HeroIconStyle.outline,
                    size: 20,
                    color: cs.outline,
                  ),
                  onTap: () => context.push(AppRoutes.privacy),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
