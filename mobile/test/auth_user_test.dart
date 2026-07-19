import 'package:flutter_test/flutter_test.dart';
import 'package:vaxiil_mobile/features/auth/domain/entities/auth_user.dart';

void main() {
  test('AuthUser parses legal acceptance status', () {
    final user = AuthUser.fromJson({
      'id': 'u1',
      'email': 'ada@example.com',
      'legal': {
        'terms_version': '2026.07.19',
        'privacy_version': '2026.07.19',
        'accepted_terms': false,
        'accepted_privacy': true,
        'needs_acceptance': true,
      },
    });

    expect(user.legal.needsAcceptance, isTrue);
    expect(user.legal.acceptedTerms, isFalse);
    expect(user.legal.termsVersion, '2026.07.19');
    expect(user.toJson()['legal'], isA<Map<String, dynamic>>());
  });

  test('AuthUser parses and serializes privacy and demographic fields', () {
    final user = AuthUser.fromJson({
      'id': 'u1',
      'email': 'ada@example.com',
      'show_email': true,
      'date_of_birth': '1990-12-10',
      'sex': {'value': 'F', 'title': 'Female', 'css': 'danger'},
      'age': 35,
    });

    expect(user.showEmail, isTrue);
    expect(user.dateOfBirth, '1990-12-10');
    expect(user.sex?.value, 'F');
    expect(user.age, 35);
    expect(user.toJson()['show_email'], isTrue);
    expect(user.toJson()['date_of_birth'], '1990-12-10');
    expect((user.toJson()['sex'] as Map<String, dynamic>)['value'], 'F');
  });
}
