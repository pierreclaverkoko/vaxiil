import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/router/app_router.dart';
import 'package:vaxiil_mobile/core/theme/theme_manager.dart';
import 'package:vaxiil_mobile/core/utils/logger.dart';
import 'package:vaxiil_mobile/core/utils/network_connectivity.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize dependency injection
  await configureDependencies();
  
  // Initialize services
  await _initializeServices();
  
  // Run the app
  runApp(const VaxiilApp());
}

Future<void> _initializeServices() async {
  try {
    // Initialize logger
    Logger.enableLogging(true);
    Logger.info('Initializing Vaxiil app...');
    
    // Initialize theme manager
    await ThemeManager().initialize();
    Logger.info('Theme manager initialized');
    
    // Initialize network connectivity
    await NetworkConnectivity().initialize();
    Logger.info('Network connectivity initialized');
    
    Logger.info('All services initialized successfully');
  } catch (e, stackTrace) {
    Logger.fatal('Failed to initialize services', error: e, stackTrace: stackTrace);
  }
}

class VaxiilApp extends StatelessWidget {
  const VaxiilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemeManagerProvider(
      themeManager: ThemeManager(),
      child: ListenableBuilder(
        listenable: ThemeManager(),
        builder: (context, child) {
          final themeManager = ThemeManagerProvider.of(context);
          
          return ScreenUtilInit(
            designSize: const Size(375, 812), // iPhone X dimensions
            minTextAdapt: true,
            splitScreenMode: true,
            builder: (context, child) {
              return MaterialApp.router(
                title: 'Vaxiil',
                debugShowCheckedModeBanner: false,
                
                // Theme configuration
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeManager.currentThemeMode,
                
                // Router configuration
                routerConfig: AppRouter.router,
                
                // Localization
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: const [
                  Locale('en', 'US'), // English
                  Locale('es', 'ES'), // Spanish
                  Locale('fr', 'FR'), // French
                  Locale('de', 'DE'), // German
                  Locale('it', 'IT'), // Italian
                  Locale('pt', 'BR'), // Portuguese
                  Locale('zh', 'CN'), // Chinese
                  Locale('ja', 'JP'), // Japanese
                  Locale('ko', 'KR'), // Korean
                ],
                
                // Builder for additional configurations
                builder: (context, child) {
                  return MediaQuery(
                    // Ensure text scale factor doesn't exceed certain limits
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.2)),
                    ),
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Builder(
                        builder: (context) {
                          // Log navigation events
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            Logger.logNavigation('app_started');
                          });
                          
                          return child!;
                        },
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
