import {
  isBookingConfirmed,
  isBookingPending,
  isPastBooking,
  isRescheduleAwaitingBusiness,
  isRescheduleAwaitingClient,
  locationTypeIcon,
  parseBookingClientBrief,
  parseBookingListItem,
  sessionHasStarted,
} from './booking';

describe('parseBookingListItem', () => {
  it('parses nested service, slots, and currency', () => {
    const item = parseBookingListItem({
      id: 'b-1',
      status: { value: 'P', title: 'Pending', css: 'warning' },
      is_paid: true,
      pending_reschedule: {
        id: 'pr-1',
        proposed_by: { value: 'C', title: 'Client', css: 'info' },
        status: { value: 'P', title: 'Pending', css: 'warning' },
        time_slots: [
          {
            start_time: '2026-08-02T10:00:00Z',
            end_time: '2026-08-02T11:00:00Z',
            location_type: 'H',
          },
        ],
        reason: 'Need morning',
      },
      total_price: '99.00',
      service: {
        id: 'svc-1',
        name: 'Yoga',
        category: { id: 'cat-1', name: 'Mind', icon: 'self_improvement' },
      },
      organization: { id: 'org-1' },
      accepted_currency: { currency: { code: 'CAD' } },
      time_slots: [
        {
          id: 'slot-1',
          start_time: '2026-08-01T14:00:00Z',
          end_time: '2026-08-01T15:00:00Z',
          location_type: { value: 'O', title: 'Office', css: 'default' },
        },
      ],
    });

    expect(item.id).toBe('b-1');
    expect(item.serviceId).toBe('svc-1');
    expect(item.serviceName).toBe('Yoga');
    expect(item.currencyCode).toBe('CAD');
    expect(item.timeSlots).toHaveLength(1);
    expect(item.status?.value).toBe('P');
    expect(item.isPaid).toBe(true);
    expect(item.paymentState).toBe('paid');
    expect(item.pendingReschedule?.proposedBy?.value).toBe('C');
    expect(item.pendingReschedule?.timeSlots[0]?.locationType?.value).toBe('H');
    expect(isRescheduleAwaitingBusiness(item)).toBe(true);
    expect(isRescheduleAwaitingClient(item)).toBe(false);
    expect(isPastBooking(item)).toBe(false);
  });
});

describe('payment_state', () => {
  it('parses refunded payment_state when unpaid after refund', () => {
    const item = parseBookingListItem({
      id: 'b-refund',
      status: { value: 'X', title: 'Cancelled', css: 'warning' },
      is_paid: false,
      payment_state: 'refunded',
      total_price: '75.00',
      service: { id: 'svc-1', name: 'Yoga' },
      organization: { id: 'org-1' },
      time_slots: [],
    });
    expect(item.isPaid).toBe(false);
    expect(item.paymentState).toBe('refunded');
  });

  it('parses processing payment_state and pending_payment_reference', () => {
    const item = parseBookingListItem({
      id: 'b-proc',
      status: { value: 'Q', title: 'Requested', css: 'info' },
      is_paid: false,
      payment_state: 'processing',
      pending_payment_reference: 'bk_abc',
      total_price: '75.00',
      service: { id: 'svc-1', name: 'Yoga' },
      organization: { id: 'org-1' },
      time_slots: [],
    });
    expect(item.isPaid).toBe(false);
    expect(item.paymentState).toBe('processing');
    expect(item.pendingPaymentReference).toBe('bk_abc');
  });
});

describe('locationTypeIcon', () => {
  it('maps venue codes to Material icons', () => {
    expect(locationTypeIcon('O')).toBe('storefront');
    expect(locationTypeIcon('H')).toBe('home');
    expect(locationTypeIcon('V')).toBe('videocam');
    expect(locationTypeIcon('B')).toBe('directions_car');
    expect(locationTypeIcon(null)).toBe('place');
  });
});

describe('sessionHasStarted', () => {
  it('is false when there are no slots or start is in the future', () => {
    expect(sessionHasStarted({ timeSlots: [] }, Date.parse('2026-08-01T12:00:00Z'))).toBe(false);
    expect(
      sessionHasStarted(
        {
          timeSlots: [
            {
              id: 's1',
              startTime: new Date('2026-08-01T14:00:00Z'),
              endTime: new Date('2026-08-01T15:00:00Z'),
              locationType: null,
              address: null,
              roomDetails: null,
              virtualMeetingLink: null,
              notes: null,
            },
          ],
        },
        Date.parse('2026-08-01T12:00:00Z'),
      ),
    ).toBe(false);
  });

  it('is true when earliest start has been reached', () => {
    expect(
      sessionHasStarted(
        {
          timeSlots: [
            {
              id: 's1',
              startTime: new Date('2026-08-01T14:00:00Z'),
              endTime: new Date('2026-08-01T15:00:00Z'),
              locationType: null,
              address: null,
              roomDetails: null,
              virtualMeetingLink: null,
              notes: null,
            },
          ],
        },
        Date.parse('2026-08-01T14:00:00Z'),
      ),
    ).toBe(true);
  });
});

describe('isBookingPending / isBookingConfirmed', () => {
  it('treats requested, draft, and rescheduled as pending', () => {
    expect(isBookingPending({ status: { value: 'Q', title: 'Requested', css: 'warning' } })).toBe(
      true,
    );
    expect(isBookingPending({ status: { value: 'D', title: 'Draft', css: 'default' } })).toBe(true);
    expect(
      isBookingPending({ status: { value: 'R', title: 'Rescheduled', css: 'warning' } }),
    ).toBe(true);
    expect(isBookingPending({ status: { value: 'F', title: 'Confirmed', css: 'success' } })).toBe(
      false,
    );
  });

  it('treats confirmed and in-progress as confirmed', () => {
    expect(isBookingConfirmed({ status: { value: 'F', title: 'Confirmed', css: 'success' } })).toBe(
      true,
    );
    expect(
      isBookingConfirmed({ status: { value: 'P', title: 'In Progress', css: 'info' } }),
    ).toBe(true);
    expect(isBookingConfirmed({ status: { value: 'Q', title: 'Requested', css: 'warning' } })).toBe(
      false,
    );
  });
});

describe('parseBookingClientBrief', () => {
  it('parses privacy-aware client fields and choice enums', () => {
    const client = parseBookingClientBrief({
      id: 'user-1',
      trust_alias: 'Moss River',
      age: 34,
      sex: { value: 'F', title: 'Female', css: 'info' },
      first_name: null,
      last_name: null,
      phone: '+12025550123',
      email: null,
    });

    expect(client).toEqual({
      id: 'user-1',
      trustAlias: 'Moss River',
      age: 34,
      sex: { value: 'F', title: 'Female', css: 'info' },
      firstName: null,
      lastName: null,
      phone: '+12025550123',
      email: null,
    });
  });
});
