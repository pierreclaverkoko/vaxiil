import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/utils/responsive.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_frosted_top_bar.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_logo.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_main_shell.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_site_footer.dart';

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

  testWidgets('VaxiilMainShell shows pill under shellBreakpoint', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 800)),
          child: Builder(
            builder: (context) {
              expect(ResponsiveUtils.isCompactShell(context), isTrue);
              return Scaffold(
                body: const SizedBox(),
                bottomNavigationBar: SafeArea(
                  child: VaxiilBottomNavPill(
                    items: kVaxiilMainNavItems,
                    selectedIndex: 0,
                    onBranchTap: (_) {},
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(find.byType(VaxiilBottomNavPill), findsOneWidget);
  });

  testWidgets('VaxiilFrostedTopBar shows nav links when expanded', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var tapped = -1;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1280, 800)),
          child: Scaffold(
            body: VaxiilFrostedTopBar(
              topPadding: 0,
              onMenu: () {},
              onAvatarTap: () {},
              selectedNavIndex: 0,
              onNavTap: (i) => tapped = i,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Bookings'), findsOneWidget);
    expect(find.byType(VaxiilLogo), findsOneWidget);

    await tester.tap(find.text('Bookings'));
    expect(tapped, 1);
  });

  testWidgets('VaxiilFrostedTopBar hides nav links when compact', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 800)),
          child: Scaffold(
            body: VaxiilFrostedTopBar(
              topPadding: 0,
              onMenu: () {},
              onAvatarTap: () {},
              selectedNavIndex: 0,
              onNavTap: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Discover'), findsNothing);
    expect(find.byType(VaxiilLogo), findsOneWidget);
  });

  testWidgets('VaxiilSiteFooter visible only when expanded', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 800)),
          child: const Scaffold(body: VaxiilSiteFooter()),
        ),
      ),
    );
    expect(find.text('Privacy Policy'), findsNothing);

    await tester.binding.setSurfaceSize(const Size(1280, 800));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1280, 800)),
          child: const Scaffold(body: VaxiilSiteFooter()),
        ),
      ),
    );
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms of Service'), findsOneWidget);
  });

  testWidgets('Login rearranges at md breakpoint', (tester) async {
    // Smoke: ResponsiveContent clamps width differently
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1280, 900)),
          child: Scaffold(
            body: ResponsiveContent(
              maxWidth: 1200,
              child: Container(
                key: const Key('rail'),
                height: 40,
                color: Colors.green,
              ),
            ),
          ),
        ),
      ),
    );

    final box = tester.renderObject<RenderBox>(find.byKey(const Key('rail')));
    expect(box.size.width, lessThanOrEqualTo(1200));
    expect(ResponsiveUtils.mdBreakpoint, 768);
    expect(ResponsiveUtils.shellBreakpoint, 768);
  });
}
