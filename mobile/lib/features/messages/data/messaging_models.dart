import 'package:vaxiil_mobile/shared/models/choice_enum_data.dart';

class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.title,
    this.kind,
    this.status,
    this.peerTrustAlias,
    this.peerAge,
    this.peerSex,
    this.lastMessageAt,
    this.lastMessagePreview = '',
    this.unread = false,
    this.isBlocked = false,
    this.bookingId,
    this.organizationId,
    this.organizationName,
  });

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    return ConversationSummary(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      kind: ChoiceEnumData.parse(json['kind']),
      status: ChoiceEnumData.parse(json['status']),
      peerTrustAlias: json['peer_trust_alias'] as String?,
      peerAge: json['peer_age'] as int?,
      peerSex: ChoiceEnumData.parse(json['peer_sex']),
      lastMessageAt: _parseDate(json['last_message_at']),
      lastMessagePreview: json['last_message_preview'] as String? ?? '',
      unread: json['unread'] == true,
      isBlocked: json['is_blocked'] == true,
      bookingId: json['booking_id']?.toString(),
      organizationId: json['organization_id']?.toString(),
      organizationName: json['organization_name'] as String?,
    );
  }

  final String id;
  final String title;
  final ChoiceEnumData? kind;
  final ChoiceEnumData? status;
  final String? peerTrustAlias;
  final int? peerAge;
  final ChoiceEnumData? peerSex;
  final DateTime? lastMessageAt;
  final String lastMessagePreview;
  final bool unread;
  final bool isBlocked;
  final String? bookingId;
  final String? organizationId;
  final String? organizationName;
}

class ConversationInviteModel {
  const ConversationInviteModel({
    required this.id,
    this.status,
    this.initiatorTrustAlias,
    this.initiatorAge,
    this.initiatorSex,
    this.createdAt,
    this.conversationId,
  });

  factory ConversationInviteModel.fromJson(Map<String, dynamic> json) {
    return ConversationInviteModel(
      id: json['id']?.toString() ?? '',
      status: ChoiceEnumData.parse(json['status']),
      initiatorTrustAlias: json['initiator_trust_alias'] as String?,
      initiatorAge: json['initiator_age'] as int?,
      initiatorSex: ChoiceEnumData.parse(json['initiator_sex']),
      createdAt: _parseDate(json['created_at']),
      conversationId: json['conversation']?.toString(),
    );
  }

  final String id;
  final ChoiceEnumData? status;
  final String? initiatorTrustAlias;
  final int? initiatorAge;
  final ChoiceEnumData? initiatorSex;
  final DateTime? createdAt;
  final String? conversationId;
}

class ConversationMessageModel {
  const ConversationMessageModel({
    required this.id,
    required this.body,
    this.createdAt,
    this.senderTrustAlias,
    this.isMine = false,
  });

  factory ConversationMessageModel.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'];
    String? alias;
    if (sender is Map) {
      alias = sender['trust_alias'] as String?;
    }
    return ConversationMessageModel(
      id: json['id']?.toString() ?? '',
      body: json['body'] as String? ?? '',
      createdAt: _parseDate(json['created_at']),
      senderTrustAlias: alias,
      isMine: json['is_mine'] == true,
    );
  }

  final String id;
  final String body;
  final DateTime? createdAt;
  final String? senderTrustAlias;
  final bool isMine;
}

DateTime? _parseDate(dynamic raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}
