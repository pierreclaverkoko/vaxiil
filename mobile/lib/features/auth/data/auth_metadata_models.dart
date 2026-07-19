import 'package:vaxiil_mobile/features/auth/domain/entities/user_legal_status.dart';

/// Response from `GET /api/v1/auth/metadata/`.
class AuthMetadata {
  const AuthMetadata({
    this.termsVersion,
    this.termsDocumentId,
    this.privacyVersion,
    this.privacyDocumentId,
    this.legal,
  });

  factory AuthMetadata.fromJson(Map<String, dynamic> json) {
    UserLegalStatus? legal;
    final rawLegal = json['legal'];
    if (rawLegal is Map<String, dynamic>) {
      legal = UserLegalStatus.fromJson(rawLegal);
    }
    return AuthMetadata(
      termsVersion: json['terms_version'] as String?,
      termsDocumentId: json['terms_document_id']?.toString(),
      privacyVersion: json['privacy_version'] as String?,
      privacyDocumentId: json['privacy_document_id']?.toString(),
      legal: legal,
    );
  }

  final String? termsVersion;
  final String? termsDocumentId;
  final String? privacyVersion;
  final String? privacyDocumentId;
  final UserLegalStatus? legal;
}
