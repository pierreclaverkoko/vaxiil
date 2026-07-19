/// Response from `GET /api/v1/legal/{terms|privacy}/?lang=`.
class LegalDocumentContent {
  const LegalDocumentContent({
    required this.id,
    required this.documentType,
    required this.version,
    required this.summary,
    required this.body,
    required this.locale,
    this.effectiveAt,
  });

  factory LegalDocumentContent.fromJson(Map<String, dynamic> json) {
    return LegalDocumentContent(
      id: json['id']?.toString() ?? '',
      documentType: json['document_type'] as String? ?? '',
      version: json['version'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      body: json['body'] as String? ?? '',
      locale: json['locale'] as String? ?? 'en',
      effectiveAt: json['effective_at'] as String?,
    );
  }

  final String id;
  final String documentType;
  final String version;
  final String summary;
  final String body;
  final String locale;
  final String? effectiveAt;
}
