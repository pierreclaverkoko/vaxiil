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

import { LocaleService } from '@/core/i18n/locale.service';

import { BookingsService } from './bookings.service';

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
      const req = await expectRequest(http, (request) =>
        request.url.endsWith(`bookings/booking-1/${action}/`),
      );
      expect(req.request.method).toBe('POST');
      req.flush({ id: 'booking-1', service: 'service-1', organization: 'org-1', time_slots: [] });

      expect((await promise).id).toBe('booking-1');
    });
  }

  it('posts to reschedule accept', async () => {
    const promise = service.acceptReschedule('booking-1');
    const req = await expectRequest(http, (request) =>
      request.url.endsWith('bookings/booking-1/reschedule/accept/'),
    );
    expect(req.request.method).toBe('POST');
    req.flush({ id: 'booking-1', service: 'service-1', organization: 'org-1', time_slots: [] });
    expect((await promise).id).toBe('booking-1');
  });

  it('posts to reschedule decline', async () => {
    const promise = service.declineReschedule('booking-1');
    const req = await expectRequest(http, (request) =>
      request.url.endsWith('bookings/booking-1/reschedule/decline/'),
    );
    expect(req.request.method).toBe('POST');
    req.flush({ id: 'booking-1', service: 'service-1', organization: 'org-1', time_slots: [] });
    expect((await promise).id).toBe('booking-1');
  });
});
