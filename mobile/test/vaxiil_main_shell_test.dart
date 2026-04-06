import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_main_shell.dart';

void main() {
  testWidgets('VaxiilBottomNavPill shows tab labels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: VaxiilBottomNavPill(
            items: kVaxiilMainNavItems,
            selectedIndex: 0,
            onBranchTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Bookings'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
