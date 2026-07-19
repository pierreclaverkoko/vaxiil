import {
  isBookingConfirmed,
  isBookingPending,
  isPastBooking,
  parseBookingClientBrief,
  parseBookingListItem,
} from './booking';

describe('parseBookingListItem', () => {
  it('parses nested service, slots, and currency', () => {
    const item = parseBookingListItem({
      id: 'b-1',
      status: { value: 'P', title: 'Pending', css: 'warning' },
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
    expect(isPastBooking(item)).toBe(false);
  });
});

describe('isBookingPending / isBookingConfirmed', () => {
  it('treats requested and draft as pending', () => {
    expect(isBookingPending({ status: { value: 'Q', title: 'Requested', css: 'warning' } })).toBe(
      true,
    );
    expect(isBookingPending({ status: { value: 'D', title: 'Draft', css: 'default' } })).toBe(true);
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
