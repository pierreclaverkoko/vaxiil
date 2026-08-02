import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/utils/responsive.dart';

/// One entry in the main pill bar (presentation only; routing lives in [GoRouter]).
class VaxiilMainNavItem {
  const VaxiilMainNavItem({
    required this.semanticLabel,
    required this.label,
    required this.icon,
  });

  final String semanticLabel;
  final String label;
  final HeroIcons icon;
}

/// Primary bottom/top tabs (indices 0–2 map to [StatefulNavigationShell.goBranch]).
/// Profile is reached via the avatar, not the bottom shell.
const kVaxiilMainNavItems = <VaxiilMainNavItem>[
  VaxiilMainNavItem(
    semanticLabel: 'Home tab',
    label: 'Home',
    icon: HeroIcons.home,
  ),
  VaxiilMainNavItem(
    semanticLabel: 'Bookings tab',
    label: 'Bookings',
    icon: HeroIcons.calendarDays,
  ),
  VaxiilMainNavItem(
    semanticLabel: 'Messages tab',
    label: 'Messages',
    icon: HeroIcons.chatBubbleLeftRight,
  ),
];

/// Pill bar only: items, selection, and tap callback (testable without [GoRouter]).
class VaxiilBottomNavPill extends StatelessWidget {
  const VaxiilBottomNavPill({
    required this.items,
    required this.selectedIndex,
    required this.onBranchTap,
    super.key,
  });

  final List<VaxiilMainNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onBranchTap;

  static const double _minTapHeight = 44;

  @override
  Widget build(BuildContext context) {
    final nav = Theme.of(context).extension<VaxiilMainNavTheme>() ??
        VaxiilMainNavTheme.light(Theme.of(context).colorScheme);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          widthFactor: 0.92,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                decoration: BoxDecoration(
                  color: nav.pillSurface,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: AppTheme.editorialShadow,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(items.length, (i) {
                    final e = items[i];
                    final selected = selectedIndex == i;
                    final fg = selected
                        ? nav.selectedForeground
                        : nav.unselectedForeground;
                    return Expanded(
                      child: Semantics(
                        label: e.semanticLabel,
                        selected: selected,
                        container: true,
                        button: true,
                        child: InkWell(
                          onTap: () => onBranchTap(i),
                          borderRadius: BorderRadius.circular(999),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: _minTapHeight,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? nav.selectedFill
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: HeroIcon(
                                      e.icon,
                                      style: selected
                                          ? HeroIconStyle.solid
                                          : HeroIconStyle.outline,
                                      size: 26,
                                      color: fg,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    e.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          fontSize: 11,
                                          fontWeight: selected
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          color: fg,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shell chrome for StatefulShellRoute.indexedStack: extendBody, navigation shell body, pill bar.
class VaxiilMainShell extends StatelessWidget {
  const VaxiilMainShell({
    required this.navigationShell,
    this.items = kVaxiilMainNavItems,
    super.key,
  });

  final StatefulNavigationShell navigationShell;
  final List<VaxiilMainNavItem> items;

  /// Which pill tab is highlighted (−1 = none).
  /// Branches: 0 home, 1 bookings, 2 messages, 3 profile, 4+ services → Home.
  static int bottomNavHighlightIndex(int currentBranchIndex) {
    if (currentBranchIndex <= 2) return currentBranchIndex;
    if (currentBranchIndex == 3) return -1; // profile via avatar
    return 0;
  }

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = navigationShell.currentIndex;
    final highlight = bottomNavHighlightIndex(current);
    final compact = MediaQuery.sizeOf(context).width <
        ResponsiveUtils.shellBreakpoint;

    return Scaffold(
      extendBody: compact,
      body: navigationShell,
      bottomNavigationBar: compact
          ? SafeArea(
              child: VaxiilBottomNavPill(
                items: items,
                selectedIndex: highlight,
                onBranchTap: _goBranch,
              ),
            )
          : null,
    );
  }
}
