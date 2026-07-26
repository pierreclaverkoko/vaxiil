import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:vaxiil_mobile/core/constants/app_constants.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_state.dart';
import 'package:vaxiil_mobile/features/messages/data/messaging_repository.dart';
import 'package:vaxiil_mobile/l10n/app_localizations.dart';
import 'package:vaxiil_mobile/shared/utils/responsive.dart';
import 'package:vaxiil_mobile/shared/widgets/soft_card.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_logo.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_site_footer.dart';

/// App information, version, and links to legal documents.
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  static const String _description =
      'Vaxiil is a SaaS wellness platform for booking massage, therapy, '
      'and space rentals—with privacy-focused features and multi-tenant '
      'business tools.';

  var _chatBusy = false;

  Future<void> _openSupportChat() async {
    if (_chatBusy) return;
    setState(() => _chatBusy = true);
    try {
      final conversation =
          await sl<MessagingRepository>().openPlatformSupport();
      if (!mounted) return;
      context.push('${AppRoutes.messages}/${conversation.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is Failure ? e.message : e.toString()),
        ),
      );
    } finally {
      if (mounted) setState(() => _chatBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

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
        children: [
          ResponsiveContent(
            narrowMaxWidth: 672,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Center(
                  child: VaxiilLogo(
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
                FilledButton.icon(
                  onPressed: _chatBusy ? null : _openSupportChat,
                  icon: const Icon(Icons.support_agent),
                  label: Text(l10n.aboutContactChat),
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
          ),
          const VaxiilSiteFooter(),
        ],
      ),
    );
  }
}
