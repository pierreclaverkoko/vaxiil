import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';

import { ApiPaths } from '@/core/constants/api-paths';
import { LocaleService } from '@/core/i18n/locale.service';
import { MessagingService } from '@/features/messages/messaging.service';
import { environment } from '../../../environments/environment';

describe('MessagingService', () => {
  let service: MessagingService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(),
        provideHttpClientTesting(),
        {
          provide: LocaleService,
          useValue: {
            t: (key: string) => key,
            locale: () => 'en',
          },
        },
      ],
    });
    service = TestBed.inject(MessagingService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    http.verify();
  });

  it('lists conversations', async () => {
    const promise = service.listConversations();
    const req = http.expectOne(
      (r) => r.url.includes('messaging/conversations/') && r.method === 'GET',
    );
    req.flush({
      count: 1,
      next: null,
      previous: null,
      results: [
        {
          id: 'c1',
          kind: { value: 'direct', title: 'Direct', css: 'primary' },
          status: { value: 'active', title: 'Active', css: 'success' },
          title: 'Quiet_River_42',
          peer_trust_alias: 'Quiet_River_42',
          last_message_at: '2026-07-25T12:00:00Z',
          last_message_preview: 'Hello',
          unread: true,
          is_blocked: false,
          booking_id: null,
          organization_id: null,
          organization_name: null,
          created_at: '2026-07-25T11:00:00Z',
        },
      ],
    });
    const page = await promise;
    expect(page.results.length).toBe(1);
    expect(page.results[0].title).toBe('Quiet_River_42');
    expect(page.results[0].unread).toBe(true);
  });

  it('submits opaque invite', async () => {
    const promise = service.submitInvite({ email: 'a@example.com' });
    const req = http.expectOne(`${environment.apiBaseUrl}${ApiPaths.messagingInvites}`);
    expect(req.request.body).toEqual({ email: 'a@example.com' });
    req.flush({ detail: 'If this person is on Vaxiil, an invitation will be sent.' });
    const detail = await promise;
    expect(detail).toBe('If this person is on Vaxiil, an invitation will be sent.');
  });
});
