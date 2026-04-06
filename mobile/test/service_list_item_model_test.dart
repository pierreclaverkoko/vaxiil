import 'package:flutter_test/flutter_test.dart';
import 'package:vaxiil_mobile/features/services/data/service_catalog_models.dart';

void main() {
  group('ServiceListItemModel', () {
    test('parses average_rating, rating_count, is_favorite when present', () {
      final m = ServiceListItemModel.fromJson({
        'id': 'a',
        'name': 'Massage',
        'description': 'd',
        'price_min': 50,
        'price_max': 50,
        'featured': false,
        'accepted_currency': {
          'currency': {'code': 'USD'},
        },
        'organization': {'id': 'o1', 'name': 'Org'},
        'sub_category': {
          'id': 's1',
          'name': 'Sub',
          'category': {
            'id': 'c1',
            'name': 'Cat',
            'icon': 'sparkles',
          },
        },
        'average_rating': 4.94,
        'rating_count': 12,
        'is_favorite': true,
      });

      expect(m.averageRating, 4.94);
      expect(m.ratingCount, 12);
      expect(m.isFavorite, isTrue);
      expect(m.ratingLabel, '4.9');
    });

    test('defaults rating and favorite when omitted', () {
      final m = ServiceListItemModel.fromJson({
        'id': 'b',
        'name': 'Yoga',
        'description': '',
        'price_min': 0,
        'price_max': 0,
        'featured': false,
        'accepted_currency': {
          'currency': {'code': 'USD'},
        },
        'organization': {'id': 'o1', 'name': 'Org'},
        'sub_category': {
          'id': 's1',
          'name': 'Sub',
          'category': {
            'id': 'c1',
            'name': 'Cat',
            'icon': '',
          },
        },
      });

      expect(m.averageRating, isNull);
      expect(m.ratingCount, isNull);
      expect(m.isFavorite, isFalse);
      expect(m.ratingLabel, isNull);
    });
  });
}
