import 'package:flutter_test/flutter_test.dart';
import 'package:heroicons/heroicons.dart';
import 'package:vaxiil_mobile/core/utils/hero_icon_from_name.dart';

void main() {
  group('heroIconFromDbName', () {
    test('returns matching icon for kebab-case name', () {
      expect(heroIconFromDbName('sparkles'), HeroIcons.sparkles);
      expect(heroIconFromDbName('heart'), HeroIcons.heart);
    });

    test('is case-insensitive', () {
      expect(heroIconFromDbName('SPARKLES'), HeroIcons.sparkles);
    });

    test('returns fallback for unknown name', () {
      expect(
        heroIconFromDbName('not-a-real-heroicon-name-xyz'),
        HeroIcons.squares2x2,
      );
    });

    test('returns fallback for null or empty', () {
      expect(heroIconFromDbName(null), HeroIcons.squares2x2);
      expect(heroIconFromDbName(''), HeroIcons.squares2x2);
      expect(heroIconFromDbName('   '), HeroIcons.squares2x2);
    });
  });
}
