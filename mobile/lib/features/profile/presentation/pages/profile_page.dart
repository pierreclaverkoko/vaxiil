import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:vaxiil_mobile/core/biometric/biometric_service.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/core/storage/secure_storage_service.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vaxiil_mobile/shared/widgets/soft_card.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _biometric = BiometricService();
  final _storage = SecureStorageService();
  var _biometricOn = false;
  var _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadBiometric();
  }

  Future<void> _loadBiometric() async {
    final enabled = await _storage.isBiometricEnabled();
    final can = await _biometric.canAuthenticate;
    if (mounted) {
      setState(() {
        _biometricOn = enabled;
        _biometricAvailable = can;
      });
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      final ok = await _biometric.authenticate(
        reason: 'Enable biometric unlock for Vaxiil',
      );
      if (!ok) return;
      await _storage.saveBiometricEnabled(true);
    } else {
      await _storage.saveBiometricEnabled(false);
    }
    setState(() => _biometricOn = value);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().state.user;
    final trustAlias = user?.trustAlias;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SoftCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: cs.surfaceContainerHighest,
                  child: HeroIcon(
                    HeroIcons.user,
                    style: HeroIconStyle.outline,
                    size: 36,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? 'Member',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? '',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (trustAlias != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Alias: $trustAlias',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SoftCard(
            child: Column(
              children: [
                ListTile(
                  leading: HeroIcon(
                    HeroIcons.pencilSquare,
                    style: HeroIconStyle.outline,
                    color: cs.primary,
                  ),
                  title: const Text('Edit profile'),
                  onTap: () => context.push(AppRoutes.editProfile),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: HeroIcon(
                    HeroIcons.eye,
                    style: HeroIconStyle.outline,
                    color: cs.primary,
                  ),
                  title: const Text('Privacy'),
                  subtitle: const Text('Real name and phone visibility'),
                  onTap: () => context.push(AppRoutes.privacySettings),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: HeroIcon(
                    HeroIcons.shieldCheck,
                    style: HeroIconStyle.outline,
                    color: cs.primary,
                  ),
                  title: const Text('Identity verification'),
                  subtitle: const Text('KYC document upload'),
                  onTap: () => context.push(AppRoutes.identityVerification),
                ),
                if (trustAlias == null) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: HeroIcon(
                      HeroIcons.sparkles,
                      style: HeroIconStyle.outline,
                      color: cs.primary,
                    ),
                    title: const Text('Generate trust alias'),
                    subtitle: const Text('Privacy-friendly display name'),
                    onTap: () async {
                      await context.read<AuthCubit>().refreshTrustAlias();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Trust alias ready'),
                          ),
                        );
                      }
                    },
                  ),
                ],
                const Divider(height: 1),
                ListTile(
                  leading: HeroIcon(
                    HeroIcons.buildingOffice2,
                    style: HeroIconStyle.outline,
                    color: cs.primary,
                  ),
                  title: const Text('Businesses'),
                  subtitle: const Text('Register or manage organizations'),
                  onTap: () => context.push(AppRoutes.businessList),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: HeroIcon(
                    HeroIcons.paintBrush,
                    style: HeroIconStyle.outline,
                    color: cs.primary,
                  ),
                  title: const Text('Appearance'),
                  subtitle: const Text('Light, dark, or system theme'),
                  onTap: () => context.push(AppRoutes.theme),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: HeroIcon(
                    HeroIcons.informationCircle,
                    style: HeroIconStyle.outline,
                    color: cs.primary,
                  ),
                  title: const Text('About'),
                  subtitle: const Text('Version and legal information'),
                  onTap: () => context.push(AppRoutes.about),
                ),
                if (_biometricAvailable) ...[
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: HeroIcon(
                      HeroIcons.fingerPrint,
                      style: HeroIconStyle.outline,
                      color: cs.primary,
                    ),
                    title: const Text('Biometric unlock'),
                    subtitle: const Text('Use fingerprint or Face ID when opening the app'),
                    value: _biometricOn,
                    onChanged: _toggleBiometric,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            onPressed: () async {
              await context.read<AuthCubit>().logout();
            },
            icon: HeroIcon(
              HeroIcons.arrowRightOnRectangle,
              style: HeroIconStyle.outline,
              color: cs.onError,
              size: 22,
            ),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
