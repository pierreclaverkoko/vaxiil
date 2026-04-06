Flutter & GoRouter Best Practices Guide

This document outlines the architectural improvements and coding standards for the VaxiilMainShell navigation component and general Flutter development.

1. Architectural: Use StatefulShellRoute

The current implementation re-renders the navigation bar on every route change because it treats each tab as a top-level route. This destroys the state of the previous page (e.g., scroll position or form data).

Best Practice: Use StatefulShellRoute.indexedStack.

Why: It maintains a separate Navigator for each tab. When a user switches from "Home" to "Profile" and back, the "Home" page remains exactly as they left it.

Implementation: In your GoRouter configuration, wrap your tab routes in a StatefulShellRoute.

2. Navigation Logic: Use Branch over String Matching

Manually checking path.startsWith(...) is error-prone and requires constant maintenance as you add new sub-routes (like /business or /services).

Best Practice: Rely on the StatefulNavigationShell.

Instead of calculating _indexForLocation manually, the StatefulNavigationShell provided by go_router gives you the currentIndex directly.

Refactor:

// Inside your Shell Widget
final StatefulNavigationShell navigationShell;

void _onTap(int index) {
  navigationShell.goBranch(
    index,
    initialLocation: index == navigationShell.currentIndex,
  );
}


3. UI/UX: Responsive Layouts & Touch Targets

Your current design uses FractionallySizedBox(widthFactor: 0.92) and Expanded columns. While visually pleasing, this creates "Target Area" issues.

Best Practices:

Touch Targets: Ensure every interactive element is at least 44x44 logical pixels.

Visual Feedback: Move the InkWell to be the parent of the entire tab area, including the label, to provide a larger tap surface.

Overflow Protection: Use Flexible instead of Expanded if labels vary in length, and always provide a minWidth or maxLines for text.

4. Troubleshooting: Fixed/Hidden Content Issues

If your page content is missing or "hidden" behind the navigation bar, it is likely due to how the Scaffold is managing its body.

The Issue:
In your code, you placed a floating-style menu inside the bottomNavigationBar slot. Because you used Align and Padding inside that slot, the Scaffold might not correctly calculate the height required for the bar, leading to the body content being covered or pushed out of view.

Best Practice:

Use extendBody: Set extendBody: true in your Scaffold. This allows the body to flow underneath the bottom navigation bar, which is essential for floating/translucent bars.

Avoid SizedBox.expand unnecessarily: Let the Scaffold handle the body constraints.

Stacking: If you want a truly custom "Floating" bar, consider using a Stack as the body where the page is the first child and the Nav Bar is the second child (wrapped in Positioned).

5. Performance: Constant Constructors & Theme Data

You are defining colors like stitchSelectedFill inside the build method.

Best Practice:

Theme Coupling: Move these colors into your ThemeData (e.g., extensions or specific ColorScheme slots).

Static Consts: Keep layout constants (padding, durations) as static const outside the build method to prevent object recreation during frames.

6. Accessibility (Semantics)

Icons and custom navigation bars often fail screen-reader tests.

Best Practice:

Wrap your navigation items in Semantics widgets.

Define label, selected, and container: true.

Example:

Semantics(
  label: 'Home Tab',
  selected: isSelected,
  onTap: () => goToTab(0),
  child: ...
)


7. Code Style: Dependency Inversion

Your widget currently knows about AppRoutes.services and AppRoutes.business. This is a "Leaky Abstraction."

Best Practice:

The Navigation Bar should be a "Dumb" UI component.

It should only receive a list of items and a callback. The logic of which sub-path belongs to which tab should live in your Router configuration or a separate Navigation Controller.

Summary Checklist

[ ] Move to StatefulShellRoute for state persistence.

[ ] Set extendBody: true in the Scaffold to fix hidden content issues.

[ ] Use Theme.of(context) for ALL colors, avoid hardcoded hex codes in widgets.

[ ] Increase tap target size for mobile users.

[ ] Implement Semantics for accessibility.

[ ] Remove hardcoded path logic from the UI layer.