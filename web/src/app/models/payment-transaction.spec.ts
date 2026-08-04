import { describe, expect, it } from 'vitest';

import { parsePaymentTransactionItem } from './payment-transaction';

describe('parsePaymentTransactionItem', () => {
  it('parses choice enums and booking id', () => {
    const row = parsePaymentTransactionItem({
      id: 't1',
      booking: 'b1',
      provider_code: 'mm_aggregator',
      amount: '50.00',
      currency_code: 'USD',
      kind: { value: 'P', title: 'Payment', css: 'primary' },
      status: { value: 'S', title: 'Succeeded', css: 'success' },
      purpose: { value: 'B', title: 'Booking payment', css: 'primary' },
      client_reference: 'ref1',
      created_at: '2026-08-01T12:00:00Z',
      payment_method: {
        id: 'm1',
        code: 'MOMO_TEST',
        name: 'Test MoMo',
        logo_url: 'https://cdn.example/momo.png',
        method_type: { value: 'M', title: 'Mobile money', css: 'info' },
      },
      account_identifier: '+25•••5678',
      can_refresh_status: true,
    });
    expect(row.id).toBe('t1');
    expect(row.bookingId).toBe('b1');
    expect(row.amount).toBe('50.00');
    expect(row.currencyCode).toBe('USD');
    expect(row.status?.value).toBe('S');
    expect(row.status?.css).toBe('success');
    expect(row.purpose?.value).toBe('B');
    expect(row.kind?.css).toBe('primary');
    expect(row.paymentMethod?.name).toBe('Test MoMo');
    expect(row.paymentMethod?.logoUrl).toBe('https://cdn.example/momo.png');
    expect(row.paymentMethod?.methodType?.value).toBe('M');
    expect(row.accountIdentifier).toBe('+25•••5678');
    expect(row.canRefreshStatus).toBe(true);
  });

  it('allows null booking for wallet top-ups', () => {
    const row = parsePaymentTransactionItem({
      id: 't2',
      booking: null,
      purpose: { value: 'W', title: 'Store credit top-up', css: 'success' },
      status: { value: 'N', title: 'Pending', css: 'warning' },
      amount: '25.00',
      currency_code: 'USD',
    });
    expect(row.bookingId).toBeNull();
    expect(row.purpose?.value).toBe('W');
    expect(row.paymentMethod).toBeNull();
    expect(row.accountIdentifier).toBe('');
    expect(row.canRefreshStatus).toBe(true);
  });

  it('parses can_refresh_status false for wallet refunds', () => {
    const row = parsePaymentTransactionItem({
      id: 't3',
      kind: { value: 'R', title: 'Refund', css: 'warning' },
      status: { value: 'U', title: 'Refunded', css: 'warning' },
      amount: '75.00',
      currency_code: 'USD',
      can_refresh_status: false,
    });
    expect(row.canRefreshStatus).toBe(false);
  });
});
