import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/locale/locale_manager.dart';
import 'package:vaxiil_mobile/core/router/app_router.dart';
import 'package:vaxiil_mobile/core/router/go_router_refresh.dart';
import 'package:vaxiil_mobile/core/theme/theme_manager.dart';
import 'package:vaxiil_mobile/core/utils/logger.dart';
import 'package:vaxiil_mobile/core/utils/network_connectivity.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vaxiil_mobile/l10n/app_localizations.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await configureDependencies();

  await _initializeServices();

  final authCubit = sl<AuthCubit>();
  // Web skips splash; restore session here so login/home redirects work.
  if (kIsWeb) {
    // ignore: unawaited_futures
    authCubit.checkSession();
  }
  final routerRefresh = GoRouterRefresh(authCubit);
  final router = buildVaxiilRouter(routerRefresh, authCubit);

  runApp(
    BlocProvider.value(
      value: authCubit,
      child: VaxiilApp(router: router),
    ),
  );
}

Future<void> _initializeServices() async {
  try {
    Logger.enableLogging(true);
    Logger.info('Initializing Vaxiil app...');

    await ThemeManager().initialize();
    Logger.info('Theme manager initialized');

    await LocaleManager().initialize();
    Logger.info('Locale manager initialized');

    await NetworkConnectivity().initialize();
    Logger.info('Network connectivity initialized');

    Logger.info('All services initialized successfully');
  } catch (e, stackTrace) {
    Logger.fatal('Failed to initialize services', error: e, stackTrace: stackTrace);
  }
}

class VaxiilApp extends StatelessWidget {
  const VaxiilApp({required this.router, super.key});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return ThemeManagerProvider(
      themeManager: ThemeManager(),
      child: ListenableBuilder(
        listenable: Listenable.merge([ThemeManager(), LocaleManager()]),
        builder: (context, child) {
          final themeManager = ThemeManagerProvider.of(context);
          final localeManager = LocaleManager();

          return ScreenUtilInit(
            designSize: const Size(375, 812),
            minTextAdapt: true,
            splitScreenMode: true,
            builder: (context, child) {
              return HeroIconTheme(
                style: HeroIconStyle.outline,
                child: MaterialApp.router(
                  title: 'Vaxiil',
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  themeMode: themeManager.currentThemeMode,
                  locale: localeManager.locale,
                  routerConfig: router,
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  supportedLocales: AppLocalizations.supportedLocales,
                  builder: (context, child) {
                    return MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(
                          MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.2),
                        ),
                      ),
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Builder(
                          builder: (context) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              Logger.logNavigation('app_started');
                            });
                            return child!;
                          },
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
