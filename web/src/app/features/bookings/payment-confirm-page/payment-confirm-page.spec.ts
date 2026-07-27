import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, Router } from '@angular/router';
import { of } from 'rxjs';
import { vi } from 'vitest';

import { LocaleService } from '@/core/i18n/locale.service';
import { BookingsService } from '@/features/bookings/bookings.service';
import { PaymentsService } from '@/features/bookings/payments.service';
import { ServicesCatalogService } from '@/features/services/services-catalog.service';
import { BookingDetail } from '@/models/booking';

import { PaymentConfirmPageComponent } from './payment-confirm-page';

describe('PaymentConfirmPageComponent', () => {
  let fixture: ComponentFixture<PaymentConfirmPageComponent>;
  let component: PaymentConfirmPageComponent;
  let payments: {
    createPaymentLink: ReturnType<typeof vi.fn>;
    getWallet: ReturnType<typeof vi.fn>;
  };

  const booking: BookingDetail = {
    id: 'b1',
    serviceId: 's1',
    organizationId: 'o1',
    status: { value: 'Q', title: 'Requested', css: 'warning' },
    isPaid: false,
    pendingReschedule: null,
    basePrice: '75.00',
    platformFeeRate: '1.00',
    platformFeeAmount: '0.75',
    platformFeePayer: { value: 'C', title: 'Client', css: 'info' },
    platformFeeSource: { value: 'G', title: 'Global', css: 'secondary' },
    inscriptionFeeAmount: '0',
    totalPrice: '75.75',
    currencyCode: 'EUR',
    createdAt: null,
    serviceName: 'Massage',
    practitionerAlias: null,
    serviceVariant: null,
    timeSlots: [],
    serviceCategory: null,
    specialRequests: null,
    cancellationReason: null,
    organizationName: 'Studio',
    organizationLogoUrl: null,
    practitioner: null,
    client: null,
    internalNotes: null,
    paymentSummary: null,
  };

  beforeEach(async () => {
    payments = {
      createPaymentLink: vi.fn().mockResolvedValue({
        url: 'https://pay.mainmoney.net/l/x',
        merchantReference: 'bk_1',
        transactionId: 't1',
        amountCharged: '75.00',
        walletApplied: '0',
        fullyPaid: false,
      }),
      getWallet: vi.fn().mockResolvedValue({ balances: [], totalCredited: '0' }),
    };

    await TestBed.configureTestingModule({
      imports: [PaymentConfirmPageComponent],
      providers: [
        {
          provide: ActivatedRoute,
          useValue: {
            snapshot: {
              paramMap: {
                get: (key: string) => (key === 'id' ? 'b1' : null),
              },
            },
            parent: null,
            paramMap: of({ get: (key: string) => (key === 'id' ? 'b1' : null) }),
          },
        },
        { provide: Router, useValue: { navigate: vi.fn().mockResolvedValue(true) } },
        {
          provide: BookingsService,
          useValue: { get: vi.fn().mockResolvedValue(booking) },
        },
        { provide: PaymentsService, useValue: payments },
        {
          provide: ServicesCatalogService,
          useValue: { getService: vi.fn().mockRejectedValue(new Error('skip')) },
        },
        {
          provide: LocaleService,
          useValue: {
            t: (key: string) => key,
            locale: () => 'en',
          },
        },
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(PaymentConfirmPageComponent);
    component = fixture.componentInstance;
  });

  it('should not create a payment link until proceed', async () => {
    await component.ngOnInit();
    expect(payments.createPaymentLink).not.toHaveBeenCalled();
  });

  it('should create payment link on proceed', async () => {
    const assign = vi.fn();
    vi.stubGlobal('location', { assign });
    await component.ngOnInit();
    // Seed booking for pay action without relying on template render.
    component['booking'].set(booking);
    await component['onProceed']();
    expect(payments.createPaymentLink).toHaveBeenCalledWith('b1', { applyWallet: false });
    expect(assign).toHaveBeenCalledWith('https://pay.mainmoney.net/l/x');
    vi.unstubAllGlobals();
  });

  it('toggles escrow with the switch when balance is available', async () => {
    payments.getWallet.mockResolvedValue({
      balances: [{ currencyCode: 'EUR', balance: '20.00' }],
      totalCredited: '20.00',
    });
    await component.ngOnInit();
    expect(component['applyEscrow']()).toBe(true);
    expect(component['canApplyEscrow']()).toBe(true);
    component['toggleEscrow']();
    expect(component['applyEscrow']()).toBe(false);
    component['toggleEscrow']();
    expect(component['applyEscrow']()).toBe(true);
  });
});
