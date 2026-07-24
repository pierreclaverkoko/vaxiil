export interface AppNotification {
  id: string;
  kind: string;
  title: string;
  body: string;
  bookingId: string | null;
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
      return 'event_available';
    case 'booking_received':
      return 'event_note';
    case 'booking_cancelled':
    case 'reschedule_declined':
      return 'event_busy';
    case 'reschedule_proposed':
      return 'schedule';
    case 'reschedule_accepted':
      return 'event_available';
    default:
      return 'notifications';
  }
}
