import 'package:equatable/equatable.dart';

/// Profile `legal` object from `GET /api/v1/auth/profile/`.
class UserLegalStatus extends Equatable {
  const UserLegalStatus({
    this.termsVersion,
    this.termsDocumentId,
    this.privacyVersion,
    this.privacyDocumentId,
    this.acceptedTerms = true,
    this.acceptedPrivacy = true,
    this.needsAcceptance = false,
  });

  factory UserLegalStatus.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const UserLegalStatus();
    }
    return UserLegalStatus(
      termsVersion: json['terms_version'] as String?,
      termsDocumentId: json['terms_document_id']?.toString(),
      privacyVersion: json['privacy_version'] as String?,
      privacyDocumentId: json['privacy_document_id']?.toString(),
      acceptedTerms: json['accepted_terms'] as bool? ?? true,
      acceptedPrivacy: json['accepted_privacy'] as bool? ?? true,
      needsAcceptance: json['needs_acceptance'] as bool? ?? false,
    );
  }

  final String? termsVersion;
  final String? termsDocumentId;
  final String? privacyVersion;
  final String? privacyDocumentId;
  final bool acceptedTerms;
  final bool acceptedPrivacy;
  final bool needsAcceptance;

  Map<String, dynamic> toJson() => {
        'terms_version': termsVersion,
        'terms_document_id': termsDocumentId,
        'privacy_version': privacyVersion,
        'privacy_document_id': privacyDocumentId,
        'accepted_terms': acceptedTerms,
        'accepted_privacy': acceptedPrivacy,
        'needs_acceptance': needsAcceptance,
      };

  @override
  List<Object?> get props => [
        termsVersion,
        termsDocumentId,
        privacyVersion,
        privacyDocumentId,
        acceptedTerms,
        acceptedPrivacy,
        needsAcceptance,
      ];
}
