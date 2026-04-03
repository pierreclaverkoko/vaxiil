// Basic Flutter widget test — mirrors app bootstrap (DI + router + Bloc).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/router/app_router.dart';
import 'package:vaxiil_mobile/core/router/go_router_refresh.dart';
import 'package:vaxiil_mobile/core/utils/logger.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vaxiil_mobile/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await configureDependencies();
    Logger.enableLogging(false);
  });

  testWidgets('Vaxiil app smoke test', (WidgetTester tester) async {
    final authCubit = sl<AuthCubit>();
    final router = buildVaxiilRouter(GoRouterRefresh(authCubit), authCubit);

    await tester.pumpWidget(
      BlocProvider.value(
        value: authCubit,
        child: VaxiilApp(router: router),
      ),
    );

    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
