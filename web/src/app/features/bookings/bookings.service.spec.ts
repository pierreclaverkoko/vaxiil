import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';

import { LocaleService } from '@/core/i18n/locale.service';

import { BookingsService } from './bookings.service';

describe('BookingsService actions', () => {
  let service: BookingsService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(),
        provideHttpClientTesting(),
        {
          provide: LocaleService,
          useValue: { t: (key: string) => key },
        },
      ],
    });
    service = TestBed.inject(BookingsService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  for (const action of ['confirm', 'reject', 'complete'] as const) {
    it(`posts to the ${action} endpoint`, async () => {
      const promise =
        action === 'reject' ? service.reject('booking-1') : service[action]('booking-1');
      const req = http.expectOne((request) =>
        request.url.endsWith(`bookings/booking-1/${action}/`),
      );
      expect(req.request.method).toBe('POST');
      req.flush({ id: 'booking-1', service: 'service-1', organization: 'org-1', time_slots: [] });

      expect((await promise).id).toBe('booking-1');
    });
  }

  it('posts to reschedule accept', async () => {
    const promise = service.acceptReschedule('booking-1');
    const req = http.expectOne((request) =>
      request.url.endsWith('bookings/booking-1/reschedule/accept/'),
    );
    expect(req.request.method).toBe('POST');
    req.flush({ id: 'booking-1', service: 'service-1', organization: 'org-1', time_slots: [] });
    expect((await promise).id).toBe('booking-1');
  });

  it('posts to reschedule decline', async () => {
    const promise = service.declineReschedule('booking-1');
    const req = http.expectOne((request) =>
      request.url.endsWith('bookings/booking-1/reschedule/decline/'),
    );
    expect(req.request.method).toBe('POST');
    req.flush({ id: 'booking-1', service: 'service-1', organization: 'org-1', time_slots: [] });
    expect((await promise).id).toBe('booking-1');
  });
});
