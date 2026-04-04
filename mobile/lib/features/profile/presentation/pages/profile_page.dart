import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:vaxiil_mobile/core/biometric/biometric_service.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/core/storage/secure_storage_service.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vaxiil_mobile/shared/widgets/soft_card.dart';
import 'package:vaxiil_mobile/shared/widgets/soft_list_divider.dart';

/// Profile header avatar radius. The card is offset downward by the same
/// amount so half the avatar overlaps the card (50% of the avatar height).
const double _kProfileAvatarRadius = 48;

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
    final roleTitle = user?.role?.title;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: _kProfileAvatarRadius),
                child: SoftCard(
                  padding: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      _kProfileAvatarRadius + 12,
                      16,
                      16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          user?.displayName ?? 'Member',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          user?.email ?? '',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        if (roleTitle != null && roleTitle.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            roleTitle,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                        if (trustAlias != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Alias: $trustAlias',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                        const SizedBox(height: 16),
                        FilledButton.tonalIcon(
                          onPressed: () => context.push(AppRoutes.editProfile),
                          icon: HeroIcon(
                            HeroIcons.pencilSquare,
                            style: HeroIconStyle.outline,
                            color: cs.primary,
                          ),
                          label: const Text('Edit profile'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                child: _ProfileAvatar(
                  radius: _kProfileAvatarRadius,
                  avatarUrl: user?.avatarUrl,
                  surfaceColor: cs.surfaceContainerHighest,
                  onSurfaceVariant: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SoftCard(
            child: Column(
              children: [
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
                const SoftListDivider(),
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
                  const SoftListDivider(),
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
                const SoftListDivider(),
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
                const SoftListDivider(),
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
                const SoftListDivider(),
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
                  const SoftListDivider(),
                  SwitchListTile(
                    secondary: HeroIcon(
                      HeroIcons.fingerPrint,
                      style: HeroIconStyle.outline,
                      color: cs.primary,
                    ),
                    title: const Text('Biometric unlock'),
                    subtitle: const Text(
                      'Use fingerprint or Face ID when opening the app',
                    ),
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

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.radius,
    required this.avatarUrl,
    required this.surfaceColor,
    required this.onSurfaceVariant,
  });

  final double radius;
  final String? avatarUrl;
  final Color surfaceColor;
  final Color onSurfaceVariant;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    final iconSize = radius * 1.1;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: surfaceColor,
        backgroundImage: CachedNetworkImageProvider(url),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: surfaceColor,
      child: HeroIcon(
        HeroIcons.user,
        style: HeroIconStyle.outline,
        size: iconSize,
        color: onSurfaceVariant,
      ),
    );
  }
}
