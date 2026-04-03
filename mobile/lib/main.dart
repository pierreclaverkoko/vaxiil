import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heroicons/heroicons.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/router/app_router.dart';
import 'package:vaxiil_mobile/core/router/go_router_refresh.dart';
import 'package:vaxiil_mobile/core/theme/theme_manager.dart';
import 'package:vaxiil_mobile/core/utils/logger.dart';
import 'package:vaxiil_mobile/core/utils/network_connectivity.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await configureDependencies();

  await _initializeServices();

  final authCubit = sl<AuthCubit>();
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
        listenable: ThemeManager(),
        builder: (context, child) {
          final themeManager = ThemeManagerProvider.of(context);

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
                  routerConfig: router,
                  localizationsDelegates: const [
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  supportedLocales: const [
                    Locale('en', 'US'),
                    Locale('es', 'ES'),
                    Locale('fr', 'FR'),
                    Locale('de', 'DE'),
                    Locale('it', 'IT'),
                    Locale('pt', 'BR'),
                    Locale('zh', 'CN'),
                    Locale('ja', 'JP'),
                    Locale('ko', 'KR'),
                  ],
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
