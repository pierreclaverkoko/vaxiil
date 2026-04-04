import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/core/theme/theme_manager.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_state.dart';

/// System / light / dark selection persisted via [ThemeManager].
class ThemeSettingsPage extends StatelessWidget {
  const ThemeSettingsPage({super.key});

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
        title: const Text('Appearance'),
      ),
      body: ListenableBuilder(
        listenable: ThemeManager(),
        builder: (context, child) {
          final themeManager = ThemeManagerProvider.of(context);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Theme',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...ThemeModeOption.values.map((mode) {
                return RadioListTile<ThemeModeOption>(
                  title: Text(themeManager.getThemeModeDisplayName(mode)),
                  value: mode,
                  groupValue: themeManager.themeMode,
                  onChanged: (value) async {
                    if (value != null) {
                      await themeManager.setThemeMode(value);
                    }
                  },
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
