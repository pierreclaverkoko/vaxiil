import { ChoiceEnum, parseChoiceEnum } from './choice-enum';
import {
  ServiceCategoryBrief,
  currencyCodeFromAcceptedJson,
  parseServiceCategoryBrief,
} from './service-catalog';

export interface BookingTimeSlot {
  id: string;
  startTime: Date | null;
  endTime: Date | null;
  locationType: ChoiceEnum | null;
  address: string | null;
  roomDetails: string | null;
  virtualMeetingLink: string | null;
  notes: string | null;
}

export interface BookingTimeSlotWrite {
  start_time: string;
  end_time: string;
  location_type: string;
  address?: string;
  room_details?: string;
  virtual_meeting_link?: string;
  notes?: string;
}

export interface BookingVariantBrief {
  id: string;
  name: string;
  durationMinutes: number;
  price: string;
}

export interface PractitionerBrief {
  id: string;
  firstName: string | null;
  lastName: string | null;
  avatarUrl: string | null;
}

export interface BookingClientBrief {
  id: string;
  trustAlias: string;
  age: number | null;
  sex: ChoiceEnum | null;
  firstName: string | null;
  lastName: string | null;
  phone: string | null;
  email: string | null;
}

export interface BookingPaymentSummaryBrief {
  netCaptured: string;
  currencyCode: string | null;
}

export interface BookingPendingReschedule {
  id: string;
  proposedBy: ChoiceEnum | null;
  status: ChoiceEnum | null;
  timeSlots: BookingTimeSlot[];
  reason: string | null;
  decidedAt: Date | null;
  createdAt: Date | null;
}

export interface BookingListItem {
  id: string;
  serviceId: string;
  organizationId: string;
  status: ChoiceEnum | null;
  isPaid: boolean;
  pendingReschedule: BookingPendingReschedule | null;
  basePrice: string;
  platformFeeRate: string;
  platformFeeAmount: string;
  platformFeePayer: ChoiceEnum | null;
  platformFeeSource: ChoiceEnum | null;
  totalPrice: string;
  currencyCode: string;
  createdAt: Date | null;
  serviceName: string | null;
  practitionerAlias: string | null;
  serviceVariant: BookingVariantBrief | null;
  timeSlots: BookingTimeSlot[];
  serviceCategory: ServiceCategoryBrief | null;
}

export interface BookingDetail extends BookingListItem {
  specialRequests: string | null;
  cancellationReason: string | null;
  organizationName: string | null;
  organizationLogoUrl: string | null;
  practitioner: PractitionerBrief | null;
  client: BookingClientBrief | null;
  internalNotes: string | null;
  paymentSummary: BookingPaymentSummaryBrief | null;
}

/** Material Symbols for Booking.LocationType codes O/H/V/B. */
export const LOCATION_TYPE_ICONS: Record<string, string> = {
  O: 'storefront',
  H: 'home',
  V: 'videocam',
  B: 'directions_car',
};

export function locationTypeIcon(value: string | number | null | undefined): string {
  if (value == null || value === '') {
    return 'place';
  }
  return LOCATION_TYPE_ICONS[String(value)] ?? 'place';
}

export interface BookingCreatePayload {
  service: string;
  service_variant?: string;
  total_price?: string;
  special_requests?: string;
  share_name?: boolean;
  share_phone?: boolean;
  share_email?: boolean;
  time_slots: BookingTimeSlotWrite[];
}

function serviceCategoryFromNestedService(rawService: unknown): ServiceCategoryBrief | null {
  if (!rawService || typeof rawService !== 'object' || Array.isArray(rawService)) {
    return null;
  }
  const category = (rawService as Record<string, unknown>)['category'];
  if (!category || typeof category !== 'object' || Array.isArray(category)) {
    return null;
  }
  const c = category as Record<string, unknown>;
  return parseServiceCategoryBrief({
    id: c['id'] != null ? String(c['id']) : '',
    name: c['name'],
    icon: c['icon'],
  });
}

function parseDate(value: unknown): Date | null {
  if (typeof value !== 'string' || !value) {
    return null;
  }
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? null : d;
}

export function parseBookingTimeSlot(json: Record<string, unknown>): BookingTimeSlot {
  return {
    id: json['id'] != null ? String(json['id']) : '',
    startTime: parseDate(json['start_time']),
    endTime: parseDate(json['end_time']),
    locationType: parseChoiceEnum(json['location_type']),
    address: typeof json['address'] === 'string' ? json['address'] : null,
    roomDetails: typeof json['room_details'] === 'string' ? json['room_details'] : null,
    virtualMeetingLink:
      typeof json['virtual_meeting_link'] === 'string' ? json['virtual_meeting_link'] : null,
    notes: typeof json['notes'] === 'string' ? json['notes'] : null,
  };
}

export function parseBookingVariantBrief(json: Record<string, unknown>): BookingVariantBrief {
  return {
    id: json['id'] != null ? String(json['id']) : '',
    name: typeof json['name'] === 'string' ? json['name'] : '',
    durationMinutes: typeof json['duration_minutes'] === 'number' ? json['duration_minutes'] : 0,
    price: json['price'] != null ? String(json['price']) : '0',
  };
}

export function parsePractitionerBrief(json: Record<string, unknown>): PractitionerBrief {
  return {
    id: json['id'] != null ? String(json['id']) : '',
    firstName: typeof json['first_name'] === 'string' ? json['first_name'] : null,
    lastName: typeof json['last_name'] === 'string' ? json['last_name'] : null,
    avatarUrl: typeof json['avatar_url'] === 'string' ? json['avatar_url'] : null,
  };
}

export function parseBookingClientBrief(json: Record<string, unknown>): BookingClientBrief {
  return {
    id: json['id'] != null ? String(json['id']) : '',
    trustAlias: typeof json['trust_alias'] === 'string' ? json['trust_alias'] : '',
    age: typeof json['age'] === 'number' ? json['age'] : null,
    sex: parseChoiceEnum(json['sex']),
    firstName: typeof json['first_name'] === 'string' ? json['first_name'] : null,
    lastName: typeof json['last_name'] === 'string' ? json['last_name'] : null,
    phone: typeof json['phone'] === 'string' ? json['phone'] : null,
    email: typeof json['email'] === 'string' ? json['email'] : null,
  };
}

export function parseBookingPaymentSummaryBrief(
  json: Record<string, unknown>,
): BookingPaymentSummaryBrief {
  return {
    netCaptured: json['net_captured'] != null ? String(json['net_captured']) : '0',
    currencyCode: typeof json['currency_code'] === 'string' ? json['currency_code'] : null,
  };
}

export function parseBookingPendingReschedule(
  raw: unknown,
): BookingPendingReschedule | null {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    return null;
  }
  const json = raw as Record<string, unknown>;
  const timeSlots: BookingTimeSlot[] = [];
  const rawSlots = json['time_slots'];
  if (Array.isArray(rawSlots)) {
    for (const slot of rawSlots) {
      if (slot && typeof slot === 'object' && !Array.isArray(slot)) {
        timeSlots.push(parseBookingTimeSlot(slot as Record<string, unknown>));
      }
    }
  }
  return {
    id: json['id'] != null ? String(json['id']) : '',
    proposedBy: parseChoiceEnum(json['proposed_by']),
    status: parseChoiceEnum(json['status']),
    timeSlots,
    reason: typeof json['reason'] === 'string' ? json['reason'] : null,
    decidedAt: parseDate(json['decided_at']),
    createdAt: parseDate(json['created_at']),
  };
}

function parseBookingCore(
  json: Record<string, unknown>,
): Omit<BookingListItem, 'id'> & { id: string } {
  const rawService = json['service'];
  let serviceId = '';
  let serviceName: string | null = null;
  let serviceCategory: ServiceCategoryBrief | null = null;
  if (rawService && typeof rawService === 'object' && !Array.isArray(rawService)) {
    const s = rawService as Record<string, unknown>;
    serviceId = s['id'] != null ? String(s['id']) : '';
    serviceName = typeof s['name'] === 'string' ? s['name'] : null;
    serviceCategory = serviceCategoryFromNestedService(s);
  } else if (rawService != null) {
    serviceId = String(rawService);
  }

  const rawOrg = json['organization'];
  let organizationId = '';
  if (rawOrg && typeof rawOrg === 'object' && !Array.isArray(rawOrg)) {
    organizationId =
      (rawOrg as Record<string, unknown>)['id'] != null
        ? String((rawOrg as Record<string, unknown>)['id'])
        : '';
  } else if (rawOrg != null) {
    organizationId = String(rawOrg);
  }

  const rawVariant = json['service_variant'];
  const serviceVariant =
    rawVariant && typeof rawVariant === 'object' && !Array.isArray(rawVariant)
      ? parseBookingVariantBrief(rawVariant as Record<string, unknown>)
      : null;

  const timeSlots: BookingTimeSlot[] = [];
  const rawSlots = json['time_slots'];
  if (Array.isArray(rawSlots)) {
    for (const slot of rawSlots) {
      if (slot && typeof slot === 'object' && !Array.isArray(slot)) {
        timeSlots.push(parseBookingTimeSlot(slot as Record<string, unknown>));
      }
    }
  }

  return {
    id: json['id'] != null ? String(json['id']) : '',
    serviceId,
    organizationId,
    status: parseChoiceEnum(json['status']),
    isPaid: json['is_paid'] === true,
    pendingReschedule: parseBookingPendingReschedule(json['pending_reschedule']),
    basePrice: json['base_price'] != null ? String(json['base_price']) : '0',
    platformFeeRate:
      json['platform_fee_rate'] != null ? String(json['platform_fee_rate']) : '0',
    platformFeeAmount:
      json['platform_fee_amount'] != null ? String(json['platform_fee_amount']) : '0',
    platformFeePayer: parseChoiceEnum(json['platform_fee_payer']),
    platformFeeSource: parseChoiceEnum(json['platform_fee_source']),
    totalPrice: json['total_price'] != null ? String(json['total_price']) : '0',
    currencyCode: currencyCodeFromAcceptedJson(json),
    createdAt: parseDate(json['created_at']),
    serviceName,
    practitionerAlias:
      typeof json['practitioner_alias'] === 'string' ? json['practitioner_alias'] : null,
    serviceVariant,
    timeSlots,
    serviceCategory,
  };
}

export function parseBookingListItem(json: Record<string, unknown>): BookingListItem {
  return parseBookingCore(json);
}

export function parseBookingDetail(json: Record<string, unknown>): BookingDetail {
  const core = parseBookingCore(json);

  const rawOrg = json['organization'];
  let organizationName: string | null = null;
  let organizationLogoUrl: string | null = null;
  if (rawOrg && typeof rawOrg === 'object' && !Array.isArray(rawOrg)) {
    const o = rawOrg as Record<string, unknown>;
    organizationName = typeof o['name'] === 'string' ? o['name'] : null;
    organizationLogoUrl = typeof o['logo'] === 'string' ? o['logo'] : null;
  }

  const rawPractitioner = json['practitioner'];
  const practitioner =
    rawPractitioner && typeof rawPractitioner === 'object' && !Array.isArray(rawPractitioner)
      ? parsePractitionerBrief(rawPractitioner as Record<string, unknown>)
      : null;

  const rawClient = json['client'];
  const client =
    rawClient && typeof rawClient === 'object' && !Array.isArray(rawClient)
      ? parseBookingClientBrief(rawClient as Record<string, unknown>)
      : null;

  const rawPay = json['payment_summary'];
  const paymentSummary =
    rawPay && typeof rawPay === 'object' && !Array.isArray(rawPay)
      ? parseBookingPaymentSummaryBrief(rawPay as Record<string, unknown>)
      : null;

  return {
    ...core,
    specialRequests: typeof json['special_requests'] === 'string' ? json['special_requests'] : null,
    cancellationReason:
      typeof json['cancellation_reason'] === 'string' ? json['cancellation_reason'] : null,
    organizationName,
    organizationLogoUrl,
    practitioner,
    client,
    internalNotes: typeof json['internal_notes'] === 'string' ? json['internal_notes'] : null,
    paymentSummary,
  };
}

export function earliestSlotStart(booking: Pick<BookingListItem, 'timeSlots'>): Date | null {
  let best: Date | null = null;
  for (const slot of booking.timeSlots) {
    const start = slot.startTime;
    if (!start) {
      continue;
    }
    if (!best || start.getTime() < best.getTime()) {
      best = start;
    }
  }
  return best;
}

export function isPastBooking(booking: Pick<BookingListItem, 'status' | 'timeSlots'>): boolean {
  const statusValue = booking.status?.value ?? '';
  if (statusValue === 'P') {
    return false;
  }
  if (statusValue === 'M' || statusValue === 'X' || statusValue === 'N') {
    return true;
  }
  const start = earliestSlotStart(booking);
  if (start && start.getTime() <= Date.now()) {
    return true;
  }
  return false;
}

export function bookingDisplayTitle(
  booking: Pick<BookingListItem, 'serviceName' | 'serviceVariant'>,
  fallback = 'Booking',
): string {
  const name = booking.serviceName?.trim();
  if (name) {
    return name;
  }
  const variantName = booking.serviceVariant?.name.trim();
  if (variantName) {
    return variantName;
  }
  return fallback;
}

export function sortedUpcomingBookingList(items: BookingListItem[]): BookingListItem[] {
  const upcoming = items.filter((b) => !isPastBooking(b));
  upcoming.sort((a, b) => {
    const ta = earliestSlotStart(a)?.getTime() ?? Number.MAX_SAFE_INTEGER;
    const tb = earliestSlotStart(b)?.getTime() ?? Number.MAX_SAFE_INTEGER;
    return ta - tb;
  });
  return upcoming;
}

export function sortedPastBookingList(items: BookingListItem[]): BookingListItem[] {
  const past = items.filter((b) => isPastBooking(b));
  past.sort((a, b) => {
    const ta = earliestSlotStart(a)?.getTime() ?? a.createdAt?.getTime() ?? 0;
    const tb = earliestSlotStart(b)?.getTime() ?? b.createdAt?.getTime() ?? 0;
    return tb - ta;
  });
  return past;
}

export function practitionerDisplayLine(
  booking: Pick<BookingDetail, 'practitioner' | 'practitionerAlias'>,
): string | null {
  const p = booking.practitioner;
  if (p) {
    const name = `${p.firstName?.trim() ?? ''} ${p.lastName?.trim() ?? ''}`.trim();
    if (name) {
      return name;
    }
  }
  const alias = booking.practitionerAlias?.trim();
  return alias || null;
}

export function formatBookingWhen(
  start: Date | null,
  end: Date | null,
  locale?: string,
): string {
  if (!start) {
    return '';
  }
  const dateFmt = new Intl.DateTimeFormat(locale, {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
  });
  const datePart = dateFmt.format(start);
  const startTime = formatBookingListTime(start, locale);
  if (end) {
    return `${datePart} · ${startTime} – ${formatBookingListTime(end, locale)}`;
  }
  return `${datePart} · ${startTime}`;
}

export function formatBookingListDate(date: Date | null, locale?: string): string {
  if (!date) {
    return '';
  }
  return new Intl.DateTimeFormat(locale, {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  }).format(date);
}

export function formatBookingListTime(date: Date | null, locale?: string): string {
  if (!date) {
    return '—';
  }
  return new Intl.DateTimeFormat(locale, {
    hour: 'numeric',
    minute: '2-digit',
  }).format(date);
}

/** Draft, requested, or pending reschedule — needs client/provider action. */
export function isBookingPending(booking: Pick<BookingListItem, 'status'>): boolean {
  const v = booking.status?.value ?? '';
  return v === 'Q' || v === 'D' || v === 'R';
}

/** Counterparty can accept/decline: client proposed → business; business proposed → client. */
export function isRescheduleAwaitingBusiness(
  booking: Pick<BookingListItem, 'pendingReschedule'>,
): boolean {
  return booking.pendingReschedule?.proposedBy?.value === 'C';
}

export function isRescheduleAwaitingClient(
  booking: Pick<BookingListItem, 'pendingReschedule'>,
): boolean {
  return booking.pendingReschedule?.proposedBy?.value === 'B';
}

/** Confirmed or in progress. */
export function isBookingConfirmed(booking: Pick<BookingListItem, 'status'>): boolean {
  const v = booking.status?.value ?? '';
  return v === 'F' || v === 'P';
}
