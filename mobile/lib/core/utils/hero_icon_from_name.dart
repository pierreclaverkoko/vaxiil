import 'package:heroicons/heroicons.dart';

/// Maps a Heroicons icon name (kebab-case, matching [HeroIcons.name]) from the
/// API to a [HeroIcons] value. Unknown or empty values use [fallback].
HeroIcons heroIconFromDbName(
  String? raw, {
  HeroIcons fallback = HeroIcons.squares2x2,
}) {
  if (raw == null || raw.isEmpty) {
    return fallback;
  }
  final n = raw.trim().toLowerCase();
  for (final icon in HeroIcons.values) {
    if (icon.name == n) {
      return icon;
    }
  }
  return fallback;
}
