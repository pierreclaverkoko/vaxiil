import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/router/app_router.dart';
import 'package:vaxiil_mobile/core/router/go_router_refresh.dart';
import 'package:vaxiil_mobile/core/utils/logger.dart';
import 'package:vaxiil_mobile/features/auth/domain/entities/auth_user.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_state.dart';
import 'package:vaxiil_mobile/l10n/app_localizations.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_authenticated_chrome.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_frosted_top_bar.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await configureDependencies();
    Logger.enableLogging(false);
  });

  testWidgets('skipSplash starts at login when unauthenticated', (tester) async {
    final authCubit = sl<AuthCubit>();
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    authCubit.emit(const AuthState(status: AuthStatus.unauthenticated));

    final router = buildVaxiilRouter(
      GoRouterRefresh(authCubit),
      authCubit,
      skipSplash: true,
    );

    await tester.pumpWidget(
      BlocProvider.value(
        value: authCubit,
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.login);
    expect(find.textContaining('holistic restoration'), findsNothing);
  });

  testWidgets('skipSplash false allows splash initial location', (tester) async {
    final authCubit = sl<AuthCubit>();
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    authCubit.emit(const AuthState(status: AuthStatus.unknown));

    final router = buildVaxiilRouter(
      GoRouterRefresh(authCubit),
      authCubit,
      skipSplash: false,
    );

    expect(
      router.routeInformationProvider.value.uri.path,
      AppRoutes.splash,
    );
  });

  testWidgets('AuthenticatedChrome shows frosted nav when expanded',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final authCubit = sl<AuthCubit>();
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    authCubit.emit(
      const AuthState(
        status: AuthStatus.authenticated,
        user: AuthUser(
          id: '1',
          email: 'a@b.com',
          username: 'a',
        ),
      ),
    );

    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        ShellRoute(
          builder: (context, state, child) {
            return VaxiilAuthenticatedChrome(child: child);
          },
          routes: [
            GoRoute(
              path: '/home',
              builder: (_, __) => const Center(child: Text('body')),
            ),
            GoRoute(
              path: '/overlay',
              pageBuilder: (context, state) => vaxiilAdaptivePage(
                context: context,
                state: state,
                modalOnWide: true,
                child: const Scaffold(
                  body: Center(child: Text('overlay-body')),
                ),
              ),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      BlocProvider.value(
        value: authCubit,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(1280, 800)),
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(VaxiilFrostedTopBar), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('body'), findsOneWidget);

    router.go('/overlay');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(VaxiilFrostedTopBar), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('overlay-body'), findsOneWidget);
  });

  test('chromeNavHighlightForPath maps booking overlays', () {
    expect(chromeNavHighlightForPath('/booking-details'), 1);
    expect(chromeNavHighlightForPath('/messages'), 2);
    expect(chromeNavHighlightForPath('/edit-profile'), 3);
    expect(chromeNavHighlightForPath('/services'), 0);
  });
}
