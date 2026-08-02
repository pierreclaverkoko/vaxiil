import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/shared/themes/vaxiil_text.dart';

/// Navigation drawer: Home, Bookings, Messages, and Profile (avatar is primary).
class VaxiilAppDrawer extends StatelessWidget {
  const VaxiilAppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vt = VaxiilText.of(context);
    final path = GoRouterState.of(context).uri.path;

    void go(String route) {
      Navigator.of(context).pop();
      context.go(route);
    }

    return Drawer(
      backgroundColor: cs.surfaceContainerLowest,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _DrawerTile(
              selected: path == AppRoutes.home,
              icon: HeroIcons.home,
              label: 'Home',
              onTap: () => go(AppRoutes.home),
              vt: vt,
              cs: cs,
            ),
            _DrawerTile(
              selected: path == AppRoutes.bookings,
              icon: HeroIcons.calendarDays,
              label: 'Bookings',
              onTap: () => go(AppRoutes.bookings),
              vt: vt,
              cs: cs,
            ),
            _DrawerTile(
              selected: path == AppRoutes.messages,
              icon: HeroIcons.chatBubbleLeftRight,
              label: 'Messages',
              onTap: () => go(AppRoutes.messages),
              vt: vt,
              cs: cs,
            ),
            _DrawerTile(
              selected: path == AppRoutes.profile,
              icon: HeroIcons.user,
              label: 'Profile',
              onTap: () => go(AppRoutes.profile),
              vt: vt,
              cs: cs,
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.vt,
    required this.cs,
  });

  final bool selected;
  final HeroIcons icon;
  final String label;
  final VoidCallback onTap;
  final VaxiilText vt;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: HeroIcon(
        icon,
        style: selected ? HeroIconStyle.solid : HeroIconStyle.outline,
        color: selected ? cs.primary : cs.onSurfaceVariant,
      ),
      title: Text(
        label,
        style: vt.drawerItem.copyWith(
          color: selected ? cs.primary : cs.onSurface,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
      selected: selected,
      onTap: onTap,
    );
  }
}
