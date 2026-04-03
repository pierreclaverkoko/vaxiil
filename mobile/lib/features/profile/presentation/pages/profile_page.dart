import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:vaxiil_mobile/core/biometric/biometric_service.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/core/storage/secure_storage_service.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
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
                  backgroundColor: AppTheme.borderColor,
                  child: HeroIcon(
                    HeroIcons.user,
                    style: HeroIconStyle.outline,
                    size: 36,
                    color: AppTheme.textSecondary,
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
                                color: AppTheme.textSecondary,
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
                    color: AppTheme.primaryVariant,
                  ),
                  title: const Text('Edit profile'),
                  onTap: () => context.push(AppRoutes.editProfile),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: HeroIcon(
                    HeroIcons.buildingOffice2,
                    style: HeroIconStyle.outline,
                    color: AppTheme.primaryVariant,
                  ),
                  title: const Text('Businesses'),
                  subtitle: const Text('Register or manage organizations'),
                  onTap: () => context.push(AppRoutes.businessList),
                ),
                if (_biometricAvailable) ...[
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: HeroIcon(
                      HeroIcons.fingerPrint,
                      style: HeroIconStyle.outline,
                      color: AppTheme.primaryVariant,
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
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await context.read<AuthCubit>().logout();
            },
            icon: HeroIcon(
              HeroIcons.arrowRightOnRectangle,
              style: HeroIconStyle.outline,
              color: Colors.white,
              size: 22,
            ),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
