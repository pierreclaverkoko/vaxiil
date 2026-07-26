/// In-app notification from `GET /api/v1/notifications/`.
class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    this.audience = 'personal',
    this.bookingId,
    this.conversationId,
    this.messageInviteId,
    this.organizationId,
    this.readAt,
    this.emailSentAt,
    this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final audience = json['audience'] as String?;
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      kind: json['kind'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      audience: audience == 'organization' || audience == 'staff'
          ? audience!
          : 'personal',
      bookingId: json['booking']?.toString(),
      conversationId: json['conversation']?.toString(),
      messageInviteId: json['message_invite']?.toString(),
      organizationId: json['organization']?.toString(),
      readAt: _parseDate(json['read_at']),
      emailSentAt: _parseDate(json['email_sent_at']),
      createdAt: _parseDate(json['created_at']),
    );
  }

  final String id;
  final String kind;
  final String title;
  final String body;

  /// `personal` | `organization` | `staff`
  final String audience;
  final String? bookingId;
  final String? conversationId;
  final String? messageInviteId;
  final String? organizationId;
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
      audience: audience,
      bookingId: bookingId,
      conversationId: conversationId,
      messageInviteId: messageInviteId,
      organizationId: organizationId,
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
