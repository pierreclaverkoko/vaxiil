export interface AppNotification {
  id: string;
  kind: string;
  title: string;
  body: string;
  bookingId: string | null;
  conversationId: string | null;
  messageInviteId: string | null;
  organizationId: string | null;
  readAt: Date | null;
  emailSentAt: Date | null;
  createdAt: Date | null;
}

function parseDate(raw: unknown): Date | null {
  if (typeof raw !== 'string' || !raw) {
    return null;
  }
  const d = new Date(raw);
  return Number.isNaN(d.getTime()) ? null : d;
}

export function parseAppNotification(json: Record<string, unknown>): AppNotification {
  return {
    id: json['id'] != null ? String(json['id']) : '',
    kind: typeof json['kind'] === 'string' ? json['kind'] : '',
    title: typeof json['title'] === 'string' ? json['title'] : '',
    body: typeof json['body'] === 'string' ? json['body'] : '',
    bookingId: json['booking'] != null ? String(json['booking']) : null,
    conversationId: json['conversation'] != null ? String(json['conversation']) : null,
    messageInviteId:
      json['message_invite'] != null ? String(json['message_invite']) : null,
    organizationId: json['organization'] != null ? String(json['organization']) : null,
    readAt: parseDate(json['read_at']),
    emailSentAt: parseDate(json['email_sent_at']),
    createdAt: parseDate(json['created_at']),
  };
}

export function isNotificationUnread(n: Pick<AppNotification, 'readAt'>): boolean {
  return n.readAt == null;
}

/** Org-facing kinds deep-link to business booking detail when orgId is known. */
export function isOrgFacingNotificationKind(kind: string): boolean {
  return kind === 'booking_received' || kind === 'reschedule_proposed';
}

export function notificationIcon(kind: string): string {
  switch (kind) {
    case 'booking_confirmed':
    case 'reschedule_accepted':
      return 'event_available';
    case 'booking_received':
      return 'event_note';
    case 'booking_cancelled':
    case 'reschedule_declined':
      return 'event_busy';
    case 'reschedule_proposed':
      return 'schedule';
    case 'payment_received':
      return 'payments';
    case 'wallet_topped_up':
      return 'account_balance_wallet';
    case 'team_invite':
      return 'group_add';
    case 'message_invite':
      return 'person_add';
    case 'message_received':
      return 'chat';
    case 'kyc_approved':
    case 'kyb_approved':
      return 'verified_user';
    case 'kyc_rejected':
    case 'kyb_rejected':
      return 'gavel';
    default:
      return 'notifications';
  }
}
