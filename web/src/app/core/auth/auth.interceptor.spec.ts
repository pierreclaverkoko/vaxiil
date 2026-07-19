import { HttpClient, provideHttpClient, withInterceptors } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { firstValueFrom } from 'rxjs';
import { vi } from 'vitest';

import { authInterceptor } from './auth.interceptor';
import { TokenStorageService } from './token-storage.service';

describe('authInterceptor', () => {
  let http: HttpClient;
  let controller: HttpTestingController;
  let storage: TokenStorageService;

  beforeEach(() => {
    localStorage.clear();
    TestBed.configureTestingModule({
      providers: [provideHttpClient(withInterceptors([authInterceptor])), provideHttpClientTesting()],
    });
    http = TestBed.inject(HttpClient);
    controller = TestBed.inject(HttpTestingController);
    storage = TestBed.inject(TokenStorageService);
  });

  afterEach(() => {
    controller.verify();
    localStorage.clear();
    vi.restoreAllMocks();
  });

  it('attaches bearer token', () => {
    storage.saveTokens('tok', 'ref');
    void firstValueFrom(http.get('/api/v1/auth/profile/'));
    const req = controller.expectOne('/api/v1/auth/profile/');
    expect(req.request.headers.get('Authorization')).toBe('Bearer tok');
    req.flush({ id: '1', email: 'a@b.com' });
  });

  it('refreshes and retries GET on 401', async () => {
    storage.saveTokens('old', 'refresh-token');
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(
      new Response(JSON.stringify({ access: 'new', refresh: 'refresh-token' }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }),
    );

    const promise = firstValueFrom(http.get('/api/v1/auth/profile/'));
    const first = controller.expectOne('/api/v1/auth/profile/');
    first.flush({ detail: 'expired' }, { status: 401, statusText: 'Unauthorized' });

    const retry = await vi.waitFor(() => {
      const match = controller.match('/api/v1/auth/profile/');
      expect(match.length).toBe(1);
      return match[0]!;
    });

    expect(retry.request.headers.get('Authorization')).toBe('Bearer new');
    retry.flush({ id: '1', email: 'a@b.com' });

    await expect(promise).resolves.toEqual({ id: '1', email: 'a@b.com' });
    expect(storage.getAccessToken()).toBe('new');
  });
});
