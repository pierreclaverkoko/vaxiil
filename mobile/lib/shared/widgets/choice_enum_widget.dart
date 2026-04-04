import 'package:flutter/material.dart';
import 'package:vaxiil_mobile/core/constants/app_constants.dart';
import 'package:vaxiil_mobile/shared/models/choice_enum_data.dart';

/// Badge for a choice object from the API (`css` = Bootstrap-style semantic).
class ChoiceEnumWidget extends StatelessWidget {
  const ChoiceEnumWidget({
    required this.choice,
    super.key,
    this.compact = true,
  });

  final ChoiceEnumData? choice;
  final bool compact;

  static Color _background(BuildContext context, String? css) {
    final cs = Theme.of(context).colorScheme;
    final key = (css ?? 'secondary').toLowerCase();
    switch (key) {
      case 'primary':
        return cs.primaryContainer;
      case 'secondary':
        return cs.surfaceContainerHighest;
      case 'success':
        return cs.tertiaryContainer;
      case 'warning':
        return cs.secondaryContainer;
      case 'danger':
        return cs.errorContainer;
      case 'info':
        return cs.primaryContainer.withOpacity(0.6);
      case 'default':
      default:
        return cs.surfaceContainerHigh;
    }
  }

  static Color _foreground(BuildContext context, String? css) {
    final cs = Theme.of(context).colorScheme;
    final key = (css ?? 'secondary').toLowerCase();
    switch (key) {
      case 'primary':
        return cs.onPrimaryContainer;
      case 'secondary':
        return cs.onSurfaceVariant;
      case 'success':
        return cs.onTertiaryContainer;
      case 'warning':
        return cs.onSecondaryContainer;
      case 'danger':
        return cs.onErrorContainer;
      case 'info':
        return cs.onPrimaryContainer;
      case 'default':
      default:
        return cs.onSurface;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = choice;
    if (c == null) {
      return const SizedBox.shrink();
    }
    final bg = _background(context, c.css);
    final fg = _foreground(context, c.css);
    final pad = compact
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 6);
    return Container(
      padding: pad,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppConstants.radiusCard / 2),
      ),
      child: Text(
        c.title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
