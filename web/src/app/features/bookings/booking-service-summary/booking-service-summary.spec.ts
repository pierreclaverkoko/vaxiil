import { ComponentFixture, TestBed } from '@angular/core/testing';

import { LocaleService } from '@/core/i18n/locale.service';
import { ServiceDetail } from '@/models/service-catalog';

import { BookingServiceSummaryComponent } from './booking-service-summary';

describe('BookingServiceSummaryComponent', () => {
  let fixture: ComponentFixture<BookingServiceSummaryComponent>;

  const service: ServiceDetail = {
    id: 's1',
    name: 'Forest Immersion',
    description: 'A calm walk among the trees.',
    priceMin: 50,
    priceMax: 80,
    currency: 'EUR',
    acceptedLocationTypes: [],
    effectiveLocationTypes: ['O', 'H', 'V', 'B'],
    showLocationOnListing: true,
    featured: false,
    requiresVerification: false,
    isActive: true,
    availabilityType: null,
    address: '',
    city: '',
    cityId: null,
    postalCode: '',
    country: '',
    latitude: null,
    longitude: null,
    maxBookingsPerDay: null,
    maxBookingsPerTimeSlot: null,
    bookingAdvanceDays: null,
    minimumBookingHours: null,
    cancellationHours: null,
    availableStartTime: null,
    availableEndTime: null,
    availableDays: null,
    seasonalStartDate: null,
    seasonalEndDate: null,
    availabilityNotes: null,
    organization: {
      id: 'o1',
      name: 'Zen Clearing',
      verificationStatus: null,
      acceptedLocationTypes: ['O', 'H', 'V', 'B'],
    },
    subCategory: {
      id: 'sc1',
      name: 'Nature',
      category: { id: 'c1', name: 'Wellness', icon: 'spa' },
    },
    primaryImage: 'https://example.com/hero.jpg',
    variants: [],
    media: [],
    featureMappings: [],
    averageRating: null,
    ratingCount: null,
  };

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [BookingServiceSummaryComponent],
      providers: [
        {
          provide: LocaleService,
          useValue: {
            t: (key: string) => key,
            locale: () => 'en',
          },
        },
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(BookingServiceSummaryComponent);
  });

  it('should render service name, org, category, and description', async () => {
    fixture.componentRef.setInput('service', service);
    await fixture.whenStable();
    const el = fixture.nativeElement as HTMLElement;
    expect(el.querySelector('.service-summary__name')?.textContent?.trim()).toBe(
      'Forest Immersion',
    );
    expect(el.querySelector('.service-summary__org')?.textContent?.trim()).toBe('Zen Clearing');
    expect(el.querySelector('.service-summary__description')?.textContent?.trim()).toContain(
      'calm walk',
    );
    expect(el.querySelector('.service-summary__chip')?.textContent).toContain('Wellness');
    expect(el.querySelector('img')?.getAttribute('src')).toBe('https://example.com/hero.jpg');
  });

  it('should fall back to booking fields when service is null', async () => {
    fixture.componentRef.setInput('service', null);
    fixture.componentRef.setInput('booking', {
      id: 'b1',
      serviceId: 's1',
      organizationId: 'o1',
      status: null,
      isPaid: false,
      paymentState: 'unpaid' as const,
      pendingPaymentReference: null,
      pendingReschedule: null,
      basePrice: '42.00',
      platformFeeRate: '0',
      platformFeeAmount: '0',
      platformFeePayer: null,
      platformFeeSource: null,
      inscriptionFeeAmount: '0',
      totalPrice: '42.00',
      currencyCode: 'EUR',
      createdAt: null,
      serviceName: 'Fallback Service',
      practitionerAlias: null,
      serviceVariant: null,
      timeSlots: [],
      serviceCategory: { id: 'c1', name: 'Massage', icon: 'spa' },
      specialRequests: null,
      cancellationReason: null,
      cancellationPenaltyApplies: false,
      organizationName: 'Studio A',
      organizationLogoUrl: null,
      practitioner: null,
      client: null,
      internalNotes: null,
      paymentSummary: null,
    });
    await fixture.whenStable();
    const el = fixture.nativeElement as HTMLElement;
    expect(el.querySelector('.service-summary__name')?.textContent?.trim()).toBe(
      'Fallback Service',
    );
    expect(el.querySelector('.service-summary__org')?.textContent?.trim()).toBe('Studio A');
    expect(el.querySelector('.service-summary__price-value')?.textContent).toBeTruthy();
  });
});
