import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, Router } from '@angular/router';
import { of } from 'rxjs';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { LocaleService } from '@/core/i18n/locale.service';
import { BookingsService } from '@/features/bookings/bookings.service';
import { PaymentsService } from '@/features/bookings/payments.service';
import { ServicesCatalogService } from '@/features/services/services-catalog.service';
import { BookingDetail } from '@/models/booking';

import { BookingDetailPageComponent } from './booking-detail-page';

function makeBooking(overrides: Partial<BookingDetail> = {}): BookingDetail {
  const start = new Date();
  start.setDate(start.getDate() + 3);
  const end = new Date(start.getTime() + 60 * 60000);
  return {
    id: 'b1',
    serviceId: 's1',
    organizationId: 'o1',
    status: { value: 'Q', title: 'Requested', css: 'warning' },
    isPaid: false,
    paymentState: 'unpaid',
    pendingPaymentReference: null,
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
    serviceName: 'Forest Immersion',
    practitionerAlias: null,
    serviceVariant: { id: 'v1', name: '60 min', durationMinutes: 60, price: '75.00' },
    timeSlots: [
      {
        id: 't1',
        startTime: start,
        endTime: end,
        locationType: { value: 'O', title: 'Office', css: 'default' },
        address: null,
        roomDetails: null,
        virtualMeetingLink: null,
        notes: null,
      },
    ],
    serviceCategory: null,
    specialRequests: null,
    cancellationReason: null,
    cancellationPenaltyApplies: false,
    organizationName: 'Zen Studio',
    organizationLogoUrl: null,
    practitioner: {
      id: 'p1',
      firstName: 'Elena',
      lastName: 'Thorne',
      avatarUrl: null,
    },
    client: null,
    internalNotes: null,
    paymentSummary: null,
    ...overrides,
  };
}

describe('BookingDetailPageComponent', () => {
  let fixture: ComponentFixture<BookingDetailPageComponent>;
  let bookings: { get: ReturnType<typeof vi.fn>; cancel: ReturnType<typeof vi.fn> };
  let payments: { refreshTransaction: ReturnType<typeof vi.fn> };
  let router: { navigate: ReturnType<typeof vi.fn>; navigateByUrl: ReturnType<typeof vi.fn> };

  async function setup(booking: BookingDetail): Promise<void> {
    bookings = {
      get: vi.fn().mockResolvedValue(booking),
      cancel: vi.fn().mockResolvedValue(undefined),
    };
    payments = {
      refreshTransaction: vi.fn().mockResolvedValue({
        status: { value: 'G', title: 'Processing', css: 'info' },
      }),
    };
    router = {
      navigate: vi.fn().mockResolvedValue(true),
      navigateByUrl: vi.fn().mockResolvedValue(true),
    };

    await TestBed.configureTestingModule({
      imports: [BookingDetailPageComponent],
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
        { provide: Router, useValue: router },
        { provide: BookingsService, useValue: bookings },
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

    fixture = TestBed.createComponent(BookingDetailPageComponent);
    fixture.detectChanges();
    await vi.waitUntil(() => !fixture.componentInstance['loading']());
    fixture.detectChanges();
  }

  beforeEach(() => {
    TestBed.resetTestingModule();
  });

  it('renders upcoming layout with sticky pay CTA', async () => {
    await setup(makeBooking());
    const el: HTMLElement = fixture.nativeElement;
    expect(el.querySelector('.booking-detail--upcoming')).toBeTruthy();
    expect(el.textContent).toContain('Forest Immersion');
    expect(el.textContent).toContain('Elena Thorne');
    expect(el.querySelector('.booking-detail__pay-bar')).toBeTruthy();
    expect(el.textContent).toContain('bookings.payNow');
  });

  it('navigates to pay confirm from Pay Now', async () => {
    await setup(makeBooking());
    fixture.componentInstance['onPay']();
    expect(router.navigate).toHaveBeenCalledWith(['/bookings', 'b1', 'pay']);
  });

  it('hides Pay now and shows Refresh status while payment is processing', async () => {
    await setup(
      makeBooking({
        paymentState: 'processing',
        pendingPaymentReference: 'bk_proc',
      }),
    );
    const el: HTMLElement = fixture.nativeElement;
    expect(el.querySelector('.booking-detail__pay-bar')).toBeFalsy();
    expect(el.textContent).not.toContain('bookings.payNow');
    expect(el.querySelector('.booking-detail__pending-pay')).toBeTruthy();
    expect(el.textContent).toContain('bookings.payProcessingRefreshHint');
    expect(el.textContent).toContain('transactions.refreshStatus');

    await fixture.componentInstance['onCheckStatus']();
    expect(payments.refreshTransaction).toHaveBeenCalledWith('bk_proc');
    expect(bookings.get).toHaveBeenCalledTimes(2);
  });

  it('shows Pay CTA for unpaid client-proposed reschedule', async () => {
    const start = new Date();
    start.setDate(start.getDate() + 5);
    const end = new Date(start.getTime() + 60 * 60000);
    await setup(
      makeBooking({
        status: { value: 'R', title: 'Rescheduled', css: 'warning' },
        pendingReschedule: {
          id: 'pr1',
          proposedBy: { value: 'C', title: 'Client', css: 'info' },
          status: { value: 'P', title: 'Pending', css: 'warning' },
          reason: null,
          timeSlots: [
            {
              id: 'pt1',
              startTime: start,
              endTime: end,
              locationType: { value: 'O', title: 'Office', css: 'default' },
              address: null,
              roomDetails: null,
              virtualMeetingLink: null,
              notes: null,
            },
          ],
          createdAt: null,
          decidedAt: null,
        },
      }),
    );
    const el: HTMLElement = fixture.nativeElement;
    expect(el.querySelector('.booking-detail__pay-bar')).toBeTruthy();
    expect(el.textContent).toContain('bookings.payNow');
  });

  it('renders past layout with payment summary and rebook', async () => {
    const pastStart = new Date();
    pastStart.setDate(pastStart.getDate() - 5);
    const pastEnd = new Date(pastStart.getTime() + 90 * 60000);
    await setup(
      makeBooking({
        status: { value: 'M', title: 'Completed', css: 'success' },
        timeSlots: [
          {
            id: 't1',
            startTime: pastStart,
            endTime: pastEnd,
            locationType: null,
            address: null,
            roomDetails: null,
            virtualMeetingLink: null,
            notes: null,
          },
        ],
        paymentSummary: {
          netCaptured: '75.00',
          currencyCode: 'EUR',
          inscriptionFeeAmount: '0',
          amountDue: '0',
          inscriptionFeeNote: '',
        },
      }),
    );
    const el: HTMLElement = fixture.nativeElement;
    expect(el.querySelector('.booking-detail--past')).toBeTruthy();
    expect(el.querySelector('.booking-detail__pay-bar')).toBeFalsy();
    expect(el.textContent).toContain('bookings.paymentSummary');
    expect(el.textContent).toContain('bookings.rebook');
  });
});
