import 'package:flutter_test/flutter_test.dart';
import 'package:vaxiil_mobile/features/auth/data/auth_metadata_models.dart';
import 'package:vaxiil_mobile/features/auth/data/legal_document_models.dart';
import 'package:vaxiil_mobile/features/auth/domain/entities/user_legal_status.dart';

void main() {
  test('AuthMetadata.fromJson maps version fields', () {
    final metadata = AuthMetadata.fromJson({
      'terms_version': '2026.07.19',
      'privacy_version': '2026.07.19',
      'terms_document_id': 't1',
      'privacy_document_id': 'p1',
    });
    expect(metadata.termsVersion, '2026.07.19');
    expect(metadata.privacyVersion, '2026.07.19');
  });

  test('UserLegalStatus.fromJson maps needs_acceptance', () {
    final legal = UserLegalStatus.fromJson({
      'needs_acceptance': true,
      'accepted_terms': false,
      'accepted_privacy': false,
    });
    expect(legal.needsAcceptance, isTrue);
  });

  test('LegalDocumentContent.fromJson maps body and locale', () {
    final doc = LegalDocumentContent.fromJson({
      'id': 'd1',
      'document_type': 'terms',
      'version': '2026.07.19',
      'summary': 'Summary',
      'body': 'Body text',
      'locale': 'fr',
    });
    expect(doc.body, 'Body text');
    expect(doc.locale, 'fr');
  });
}
