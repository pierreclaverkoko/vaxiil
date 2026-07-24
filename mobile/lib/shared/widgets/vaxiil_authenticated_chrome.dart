import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vaxiil_mobile/shared/utils/responsive.dart';
import 'package:vaxiil_mobile/shared/utils/shell_nav.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_app_drawer.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_frosted_top_bar.dart';

/// Wide-screen authenticated chrome: frosted top bar + drawer around [child].
///
/// On compact widths this is a pass-through so pages keep their own mobile chrome.
class VaxiilAuthenticatedChrome extends StatefulWidget {
  const VaxiilAuthenticatedChrome({required this.child, super.key});

  final Widget child;

  @override
  State<VaxiilAuthenticatedChrome> createState() =>
      _VaxiilAuthenticatedChromeState();
}

class _VaxiilAuthenticatedChromeState extends State<VaxiilAuthenticatedChrome> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  int? _selectedNavIndex(String path) {
    final fromShell = mainShellSelectedIndex(context);
    if (fromShell != null) return fromShell;
    if (path.startsWith(AppRoutes.bookings) ||
        path.startsWith('/booking-')) {
      return 1;
    }
    if (path.startsWith(AppRoutes.messages)) return 2;
    if (path.startsWith(AppRoutes.profile) ||
        path.startsWith(AppRoutes.editProfile) ||
        path.startsWith(AppRoutes.notifications) ||
        path.startsWith(AppRoutes.privacySettings) ||
        path.startsWith(AppRoutes.identityVerification) ||
        path.startsWith(AppRoutes.paymentMethods) ||
        path.startsWith(AppRoutes.favorites) ||
        path.startsWith(AppRoutes.settings) ||
        path.startsWith(AppRoutes.language)) {
      return 3;
    }
    // Home / services / business / overlays → Discover
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final expanded = context.isExpandedShell;
    if (!expanded) {
      return widget.child;
    }

    final user = context.watch<AuthCubit>().state.user;
    final path = GoRouterState.of(context).uri.path;
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      key: _scaffoldKey,
      primary: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      drawer: const VaxiilAppDrawer(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VaxiilFrostedTopBar(
            topPadding: topInset,
            onMenu: () => _scaffoldKey.currentState?.openDrawer(),
            onAvatarTap: () => context.go(AppRoutes.profile),
            avatarUrl: user?.avatarUrl,
            selectedNavIndex: _selectedNavIndex(path),
            onNavTap: (i) => goMainShellBranch(context, i),
            showMenuWhenExpanded: true,
          ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}

/// Highlight index helper for tests / overlays when shell is not in the tree.
int chromeNavHighlightForPath(String path) {
  if (path.startsWith(AppRoutes.bookings) || path.startsWith('/booking-')) {
    return 1;
  }
  if (path.startsWith(AppRoutes.messages)) return 2;
  if (path.startsWith(AppRoutes.profile) ||
      path.startsWith(AppRoutes.editProfile) ||
      path.startsWith(AppRoutes.notifications) ||
      path.startsWith(AppRoutes.privacySettings) ||
      path.startsWith(AppRoutes.identityVerification)) {
    return 3;
  }
  return 0;
}
