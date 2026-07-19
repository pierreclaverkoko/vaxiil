import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';

import { PaymentsService } from './payments.service';

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

  it('creates a payment link for a booking', async () => {
    const promise = service.createPaymentLink('bk-1');
    const req = http.expectOne(
      (r) => r.url.includes('payments/bookings/bk-1/payment-link/') && r.method === 'POST',
    );
    req.flush({
      url: 'https://pay.example/checkout',
      merchant_reference: 'bk_bk-1_x',
      transaction_id: 'txn-1',
      amount_charged: '75.00',
      wallet_applied: '0',
      fully_paid: false,
    });
    const result = await promise;
    expect(result.url).toBe('https://pay.example/checkout');
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
});
