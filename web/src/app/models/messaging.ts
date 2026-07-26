import { ChoiceEnum, parseChoiceEnum } from '@/models/choice-enum';

export interface MessageSender {
  kind: 'user' | 'org_member' | 'support_agent';
  trustAlias: string | null;
  membershipId: string | null;
  displayName: string | null;
}

export interface ConversationMessage {
  id: string;
  body: string;
  createdAt: Date | null;
  sender: MessageSender;
  isMine: boolean;
}

export interface ConversationSummary {
  id: string;
  kind: ChoiceEnum | null;
  status: ChoiceEnum | null;
  title: string;
  peerTrustAlias: string | null;
  peerAge: number | null;
  peerSex: ChoiceEnum | null;
  lastMessageAt: Date | null;
  lastMessagePreview: string;
  unread: boolean;
  isBlocked: boolean;
  bookingId: string | null;
  organizationId: string | null;
  organizationName: string | null;
  createdAt: Date | null;
}

export interface ConversationInvite {
  id: string;
  status: ChoiceEnum | null;
  initiatorTrustAlias: string | null;
  initiatorAge: number | null;
  initiatorSex: ChoiceEnum | null;
  createdAt: Date | null;
  conversationId: string | null;
}

function parseDate(raw: unknown): Date | null {
  if (typeof raw !== 'string' || !raw) {
    return null;
  }
  const d = new Date(raw);
  return Number.isNaN(d.getTime()) ? null : d;
}

function asRecord(raw: unknown): Record<string, unknown> {
  return raw && typeof raw === 'object' && !Array.isArray(raw)
    ? (raw as Record<string, unknown>)
    : {};
}

export function parseMessageSender(raw: unknown): MessageSender {
  const m = asRecord(raw);
  const kindRaw = m['kind'];
  const kind =
    kindRaw === 'org_member'
      ? 'org_member'
      : kindRaw === 'support_agent'
        ? 'support_agent'
        : 'user';
  return {
    kind,
    trustAlias: typeof m['trust_alias'] === 'string' ? m['trust_alias'] : null,
    membershipId: typeof m['membership_id'] === 'string' ? m['membership_id'] : null,
    displayName: typeof m['display_name'] === 'string' ? m['display_name'] : null,
  };
}

export function parseConversationMessage(raw: unknown): ConversationMessage {
  const m = asRecord(raw);
  return {
    id: String(m['id'] ?? ''),
    body: typeof m['body'] === 'string' ? m['body'] : '',
    createdAt: parseDate(m['created_at']),
    sender: parseMessageSender(m['sender']),
    isMine: Boolean(m['is_mine']),
  };
}

export function parseConversationSummary(raw: unknown): ConversationSummary {
  const m = asRecord(raw);
  return {
    id: String(m['id'] ?? ''),
    kind: parseChoiceEnum(m['kind']),
    status: parseChoiceEnum(m['status']),
    title: typeof m['title'] === 'string' ? m['title'] : '',
    peerTrustAlias:
      typeof m['peer_trust_alias'] === 'string' ? m['peer_trust_alias'] : null,
    peerAge: typeof m['peer_age'] === 'number' ? m['peer_age'] : null,
    peerSex: parseChoiceEnum(m['peer_sex']),
    lastMessageAt: parseDate(m['last_message_at']),
    lastMessagePreview:
      typeof m['last_message_preview'] === 'string' ? m['last_message_preview'] : '',
    unread: Boolean(m['unread']),
    isBlocked: Boolean(m['is_blocked']),
    bookingId: typeof m['booking_id'] === 'string' ? m['booking_id'] : null,
    organizationId:
      typeof m['organization_id'] === 'string' ? m['organization_id'] : null,
    organizationName:
      typeof m['organization_name'] === 'string' ? m['organization_name'] : null,
    createdAt: parseDate(m['created_at']),
  };
}

export function parseConversationInvite(raw: unknown): ConversationInvite {
  const m = asRecord(raw);
  return {
    id: String(m['id'] ?? ''),
    status: parseChoiceEnum(m['status']),
    initiatorTrustAlias:
      typeof m['initiator_trust_alias'] === 'string'
        ? m['initiator_trust_alias']
        : null,
    initiatorAge: typeof m['initiator_age'] === 'number' ? m['initiator_age'] : null,
    initiatorSex: parseChoiceEnum(m['initiator_sex']),
    createdAt: parseDate(m['created_at']),
    conversationId:
      typeof m['conversation'] === 'string'
        ? m['conversation']
        : m['conversation'] != null
          ? String(m['conversation'])
          : null,
  };
}

export function conversationInitials(title: string): string {
  const parts = title.replace(/_/g, ' ').trim().split(/\s+/).filter(Boolean);
  if (!parts.length) {
    return '?';
  }
  if (parts.length === 1) {
    return parts[0].slice(0, 2).toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}
