import 'package:flutter/material.dart';

/// A low-contrast horizontal rule with side insets for grouped [ListTile] rows.
class SoftListDivider extends StatelessWidget {
  /// Creates a [SoftListDivider].
  const SoftListDivider({super.key});

  static const double _indent = 16;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: _indent,
      endIndent: _indent,
      color: cs.outlineVariant.withOpacity(0.55),
    );
  }
}
