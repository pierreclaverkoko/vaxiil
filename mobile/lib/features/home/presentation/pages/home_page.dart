import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:heroicons/heroicons.dart';
import 'package:vaxiil_mobile/core/biometric/biometric_service.dart';
import 'package:vaxiil_mobile/core/storage/secure_storage_service.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/widgets/soft_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static var _biometricGateDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeBiometricUnlock());
  }

  Future<void> _maybeBiometricUnlock() async {
    if (_biometricGateDone) return;
    final storage = SecureStorageService();
    if (!await storage.isBiometricEnabled()) {
      _biometricGateDone = true;
      return;
    }
    final bio = BiometricService();
    if (!await bio.canAuthenticate) {
      _biometricGateDone = true;
      return;
    }
    _biometricGateDone = true;
    final ok = await bio.authenticate(reason: 'Unlock Vaxiil');
    if (!mounted) return;
    if (!ok) await context.read<AuthCubit>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().state.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SoftCard(
            child: Row(
              children: [
                HeroIcon(
                  HeroIcons.sparkles,
                  style: HeroIconStyle.outline,
                  color: AppTheme.primaryVariant,
                  size: 36,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, ${user?.displayName ?? 'there'}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Discover wellness services tailored for you.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
