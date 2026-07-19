import { ComponentFixture, TestBed } from '@angular/core/testing';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { LocaleService } from '@/core/i18n/locale.service';
import { BookingListItem } from '@/models/booking';

import { BookingListPanelComponent } from './booking-list-panel';

function makeBooking(overrides: Partial<BookingListItem> = {}): BookingListItem {
  const start = new Date();
  start.setDate(start.getDate() + 2);
  return {
    id: 'b1',
    serviceId: 's1',
    organizationId: 'o1',
    status: { value: 'F', title: 'Confirmed', css: 'success' },
    basePrice: '50.00',
    platformFeeRate: '1.00',
    platformFeeAmount: '0.50',
    platformFeePayer: { value: 'C', title: 'Client', css: 'info' },
    platformFeeSource: { value: 'G', title: 'Global', css: 'secondary' },
    totalPrice: '50.50',
    currencyCode: 'EUR',
    createdAt: null,
    serviceName: 'Deep Tissue',
    practitionerAlias: 'Elena',
    serviceVariant: null,
    timeSlots: [
      {
        id: 't1',
        startTime: start,
        endTime: new Date(start.getTime() + 3600000),
        locationType: null,
        address: null,
        roomDetails: null,
        virtualMeetingLink: null,
        notes: null,
      },
    ],
    serviceCategory: { id: 'c1', name: 'Massage', icon: 'spa' },
    ...overrides,
  };
}

describe('BookingListPanelComponent', () => {
  let fixture: ComponentFixture<BookingListPanelComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [BookingListPanelComponent],
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

    fixture = TestBed.createComponent(BookingListPanelComponent);
    fixture.componentRef.setInput('upcoming', [makeBooking()]);
    fixture.componentRef.setInput('past', [
      makeBooking({
        id: 'b2',
        status: { value: 'M', title: 'Completed', css: 'default' },
      }),
    ]);
    fixture.detectChanges();
  });

  it('renders segmented tabs and confirmed card actions', () => {
    const el: HTMLElement = fixture.nativeElement;
    expect(el.querySelectorAll('[role="tab"]').length).toBe(2);
    expect(el.textContent).toContain('Deep Tissue');
    expect(el.textContent).toContain('Elena');
    expect(el.textContent).toContain('bookings.reschedule');
    expect(el.textContent).toContain('bookings.viewDetails');
  });

  it('emits viewDetails when primary CTA is clicked', () => {
    const spy = vi.fn();
    fixture.componentInstance.viewDetails.subscribe(spy);
    const buttons = fixture.nativeElement.querySelectorAll(
      '.booking-card__actions app-button',
    ) as NodeListOf<HTMLElement>;
    expect(buttons.length).toBe(2);
    buttons[1].querySelector('button')?.click();
    expect(spy).toHaveBeenCalledWith(expect.objectContaining({ id: 'b1' }));
  });

  it('switches to past segment and emits view details', () => {
    const spy = vi.fn();
    fixture.componentInstance.viewDetails.subscribe(spy);
    const tabs = fixture.nativeElement.querySelectorAll(
      '[role="tab"]',
    ) as NodeListOf<HTMLButtonElement>;
    tabs[1].click();
    fixture.detectChanges();
    expect(fixture.nativeElement.textContent).toContain('bookings.viewDetails');
    const pastButton = fixture.nativeElement.querySelector(
      '.booking-card--past app-button button',
    ) as HTMLButtonElement | null;
    pastButton?.click();
    expect(spy).toHaveBeenCalledWith(expect.objectContaining({ id: 'b2' }));
  });

  it('shows check-in CTA for pending bookings', () => {
    fixture.componentRef.setInput('upcoming', [
      makeBooking({
        status: { value: 'Q', title: 'Requested', css: 'warning' },
      }),
    ]);
    fixture.detectChanges();
    const el: HTMLElement = fixture.nativeElement;
    expect(el.textContent).toContain('bookings.actionRequired');
    expect(el.textContent).toContain('bookings.completeCheckIn');
  });
});
