import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { beforeEach, describe, expect, it } from 'vitest';

import { LocaleService } from '@/core/i18n/locale.service';

import { NotificationsService } from './notifications.service';

describe('NotificationsService', () => {
  let service: NotificationsService;
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
    service = TestBed.inject(NotificationsService);
    http = TestBed.inject(HttpTestingController);
  });

  it('lists notifications', async () => {
    const promise = service.list();
    const req = http.expectOne((r) => r.url.includes('notifications/') && r.method === 'GET');
    req.flush({
      count: 1,
      next: null,
      previous: null,
      results: [
        {
          id: 'n1',
          kind: 'booking_confirmed',
          title: 'Confirmed',
          body: 'Done',
          booking: 'b1',
          read_at: null,
          email_sent_at: null,
          created_at: '2026-07-20T10:00:00Z',
        },
      ],
    });
    const page = await promise;
    expect(page.results).toHaveLength(1);
    expect(page.results[0].title).toBe('Confirmed');
    expect(page.results[0].bookingId).toBe('b1');
  });

  it('marks one and all as read', async () => {
    const one = service.markRead('n1');
    const req1 = http.expectOne((r) => r.url.includes('notifications/n1/mark-read/'));
    req1.flush({
      id: 'n1',
      kind: 'booking_confirmed',
      title: 'Confirmed',
      body: 'Done',
      booking: null,
      read_at: '2026-07-20T11:00:00Z',
      email_sent_at: null,
      created_at: '2026-07-20T10:00:00Z',
    });
    expect((await one).readAt).toBeTruthy();

    const all = service.markAllRead();
    const req2 = http.expectOne((r) => r.url.includes('notifications/mark-all-read/'));
    req2.flush({ updated: 3 });
    expect(await all).toBe(3);
  });
});
