import 'package:flutter_test/flutter_test.dart';
import 'package:vaxiil_mobile/features/messages/data/messaging_models.dart';

void main() {
  test('ConversationSummary.fromJson parses privacy-safe fields', () {
    final c = ConversationSummary.fromJson({
      'id': 'c1',
      'title': 'Quiet_River_42',
      'kind': {'value': 'direct', 'title': 'Direct', 'css': 'primary'},
      'status': {'value': 'active', 'title': 'Active', 'css': 'success'},
      'peer_trust_alias': 'Quiet_River_42',
      'last_message_preview': 'Hello',
      'unread': true,
      'is_blocked': false,
    });
    expect(c.id, 'c1');
    expect(c.kind?.value, 'direct');
    expect(c.unread, isTrue);
    expect(c.peerTrustAlias, 'Quiet_River_42');
  });

  test('ConversationMessageModel.fromJson uses is_mine', () {
    final m = ConversationMessageModel.fromJson({
      'id': 'm1',
      'body': 'Hi',
      'is_mine': true,
      'sender': {'kind': 'user', 'trust_alias': 'ABC-1234'},
    });
    expect(m.isMine, isTrue);
    expect(m.senderTrustAlias, 'ABC-1234');
  });
}
