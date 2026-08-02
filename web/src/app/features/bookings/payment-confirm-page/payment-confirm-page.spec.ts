import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, Router } from '@angular/router';
import { of } from 'rxjs';
import { vi } from 'vitest';

import { LocaleService } from '@/core/i18n/locale.service';
import { BookingsService } from '@/features/bookings/bookings.service';
import { PaymentsService } from '@/features/bookings/payments.service';
import { ServicesCatalogService } from '@/features/services/services-catalog.service';
import { BookingDetail } from '@/models/booking';
import { PaymentCatalogService } from '@/shared/payments/payment-catalog.service';

import { PaymentConfirmPageComponent } from './payment-confirm-page';

describe('PaymentConfirmPageComponent', () => {
  let fixture: ComponentFixture<PaymentConfirmPageComponent>;
  let component: PaymentConfirmPageComponent;
  let payments: {
    collectForBooking: ReturnType<typeof vi.fn>;
    getWallet: ReturnType<typeof vi.fn>;
    getTransaction: ReturnType<typeof vi.fn>;
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
      collectForBooking: vi.fn().mockResolvedValue({
        merchantReference: 'bk_1',
        transactionId: 't1',
        amountCharged: '75.00',
        walletApplied: '0',
        fullyPaid: false,
        status: 'G',
        message: '',
      }),
      getWallet: vi.fn().mockResolvedValue({ balances: [], totalCredited: '0' }),
      getTransaction: vi.fn().mockResolvedValue({ status: 'G' }),
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
          provide: PaymentCatalogService,
          useValue: { listMethods: vi.fn().mockResolvedValue([]) },
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

  it('should not collect until user submits', async () => {
    await component.ngOnInit();
    expect(payments.collectForBooking).not.toHaveBeenCalled();
  });

  it('should collect on panel submit', async () => {
    await component.ngOnInit();
    component['booking'].set(booking);
    await component['onCollect']({
      operation: 'collect',
      method: {
        id: 'm1',
        code: 'MOMO_KE',
        name: 'M-Pesa',
        logoUrl: null,
        methodType: null,
        connectorCode: 'mm_aggregator',
        countryCode: 'KE',
        currencyCode: null,
        destinationFields: ['phone_number'],
        supportedOperations: ['collect'],
      },
      accountIdentifier: '+254700000001',
    });
    expect(payments.collectForBooking).toHaveBeenCalledWith('b1', {
      applyWallet: false,
      destination: {
        paymentMethodId: 'm1',
        accountIdentifier: '+254700000001',
        accountName: undefined,
        details: undefined,
      },
    });
    expect(component['pendingCollect']()).toBe(true);
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
