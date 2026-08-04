import { provideHttpClient } from '@angular/common/http';
import {
  HttpTestingController,
  TestRequest,
  provideHttpClientTesting,
} from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('@/core/utils/client-location', () => ({
  withOptionalClientLocation: async (body: Record<string, unknown> = {}) => body,
  optionalClientLocation: async () => null,
}));

import { PaymentsService } from './payments.service';

async function expectRequest(
  http: HttpTestingController,
  match: (req: TestRequest['request']) => boolean,
): Promise<TestRequest> {
  for (let i = 0; i < 20; i++) {
    await Promise.resolve();
    const found = http.match((r) => match(r));
    if (found.length === 1) {
      return found[0];
    }
    if (found.length > 1) {
      throw new Error(`Expected one request, found ${found.length}`);
    }
  }
  return http.expectOne((r) => match(r));
}

describe('PaymentsService', () => {
  let service: PaymentsService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    service = TestBed.inject(PaymentsService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    http.verify();
  });

  it('collects payment for a booking', async () => {
    const promise = service.collectForBooking('bk-1', {
      destination: {
        paymentMethodId: 'm1',
        accountIdentifier: '+254700000001',
      },
    });
    const req = await expectRequest(
      http,
      (r) => r.url.includes('payments/bookings/bk-1/payment-link/') && r.method === 'POST',
    );
    expect(req.request.body['payment_method_id']).toBe('m1');
    expect(req.request.body['account_identifier']).toBe('+254700000001');
    req.flush({
      merchant_reference: 'bk_bk-1_x',
      transaction_id: 'txn-1',
      amount_charged: '75.00',
      wallet_applied: '0',
      fully_paid: false,
      status: 'G',
      message: 'pending',
    });
    const result = await promise;
    expect(result.merchantReference).toBe('bk_bk-1_x');
    expect(result.fullyPaid).toBe(false);
  });

  it('loads refund wallet summary', async () => {
    const promise = service.getWallet();
    const req = http.expectOne((r) => r.url.includes('payments/wallet/') && r.method === 'GET');
    req.flush({
      balances: [{ currency_code: 'USD', balance: '40.00' }],
      total_credited: '40.00',
      ledger: [],
    });
    const result = await promise;
    expect(result.balances).toEqual([{ currencyCode: 'USD', balance: '40.00' }]);
    expect(result.totalCredited).toBe('40.00');
  });

  it('lists payment transactions with status filter', async () => {
    const promise = service.listTransactions({ page: 1, status: 'S' });
    const req = await expectRequest(
      http,
      (r) => r.url.includes('payments/transactions/') && r.method === 'GET',
    );
    expect(req.request.params.get('status')).toBe('S');
    req.flush({
      count: 1,
      next: null,
      previous: null,
      results: [
        {
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
            logo_url: null,
            method_type: { value: 'M', title: 'Mobile money', css: 'info' },
          },
          account_identifier: '+25•••5678',
        },
      ],
    });
    const page = await promise;
    expect(page.count).toBe(1);
    expect(page.results[0].bookingId).toBe('b1');
    expect(page.results[0].status?.css).toBe('success');
    expect(page.results[0].paymentMethod?.name).toBe('Test MoMo');
    expect(page.results[0].accountIdentifier).toBe('+25•••5678');
  });
});
