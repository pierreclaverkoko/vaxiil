/// In-app notification from `GET /api/v1/notifications/`.
class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    this.bookingId,
    this.readAt,
    this.emailSentAt,
    this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      kind: json['kind'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      bookingId: json['booking']?.toString(),
      readAt: _parseDate(json['read_at']),
      emailSentAt: _parseDate(json['email_sent_at']),
      createdAt: _parseDate(json['created_at']),
    );
  }

  final String id;
  final String kind;
  final String title;
  final String body;
  final String? bookingId;
  final DateTime? readAt;
  final DateTime? emailSentAt;
  final DateTime? createdAt;

  bool get isUnread => readAt == null;

  NotificationModel copyWith({
    DateTime? readAt,
    bool clearReadAt = false,
  }) {
    return NotificationModel(
      id: id,
      kind: kind,
      title: title,
      body: body,
      bookingId: bookingId,
      readAt: clearReadAt ? null : (readAt ?? this.readAt),
      emailSentAt: emailSentAt,
      createdAt: createdAt,
    );
  }

  /// Org-facing kinds deep-link to business booking detail when org id is known.
  static bool isOrgFacingKind(String kind) =>
      kind == 'booking_received' || kind == 'reschedule_proposed';
}

DateTime? _parseDate(dynamic raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}
