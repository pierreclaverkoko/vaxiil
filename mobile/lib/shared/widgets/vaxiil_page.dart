import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vaxiil_mobile/shared/utils/responsive.dart';

/// Max width for wide-screen modal panels (matches [ResponsiveContent] narrow).
const double kVaxiilModalMaxWidth = 720;

/// Builds a full-screen [MaterialPage] on compact widths, or a dismissible
/// centered modal panel over a dimmed barrier when expanded (≥768).
Page<void> vaxiilAdaptivePage({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
  bool modalOnWide = false,
}) {
  final wide = MediaQuery.sizeOf(context).width >=
      ResponsiveUtils.shellBreakpoint;
  if (modalOnWide && wide) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.45),
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
            child: child,
          ),
        );
      },
      child: _VaxiilWideModalFrame(child: child),
    );
  }
  return MaterialPage<void>(
    key: state.pageKey,
    child: child,
  );
}

class _VaxiilWideModalFrame extends StatelessWidget {
  const _VaxiilWideModalFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.92;
    return SafeArea(
      child: Align(
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: kVaxiilModalMaxWidth,
              maxHeight: maxH,
            ),
            child: Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              color: Theme.of(context).colorScheme.surface,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
