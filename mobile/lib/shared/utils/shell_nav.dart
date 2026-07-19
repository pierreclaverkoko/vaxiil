import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_main_shell.dart';

/// Navigate primary shell tabs (0–3) from frosted top bar or elsewhere.
void goMainShellBranch(BuildContext context, int index) {
  final shell = StatefulNavigationShell.maybeOf(context);
  if (shell != null) {
    shell.goBranch(
      index,
      initialLocation: index == shell.currentIndex,
    );
    return;
  }
  switch (index) {
    case 0:
      context.go(AppRoutes.home);
    case 1:
      context.go(AppRoutes.bookings);
    case 2:
      context.go(AppRoutes.messages);
    case 3:
      context.go(AppRoutes.profile);
    default:
      context.go(AppRoutes.home);
  }
}

int? mainShellSelectedIndex(BuildContext context) {
  final shell = StatefulNavigationShell.maybeOf(context);
  if (shell == null) return null;
  return VaxiilMainShell.bottomNavHighlightIndex(shell.currentIndex);
}
