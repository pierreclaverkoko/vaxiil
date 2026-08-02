import { HttpClient, provideHttpClient, withInterceptors } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { firstValueFrom } from 'rxjs';
import { vi } from 'vitest';

import { authInterceptor } from './auth.interceptor';
import { AuthService } from './auth.service';
import { TokenStorageService } from './token-storage.service';

describe('authInterceptor', () => {
  let http: HttpClient;
  let controller: HttpTestingController;
  let storage: TokenStorageService;
  let auth: AuthService;

  beforeEach(() => {
    localStorage.clear();
    TestBed.configureTestingModule({
      providers: [provideHttpClient(withInterceptors([authInterceptor])), provideHttpClientTesting()],
    });
    http = TestBed.inject(HttpClient);
    controller = TestBed.inject(HttpTestingController);
    storage = TestBed.inject(TokenStorageService);
    auth = TestBed.inject(AuthService);
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

  it('soft-clears session and retries anonymously when refresh is expired', async () => {
    storage.saveTokens('old', 'refresh-token');
    const clearSpy = vi.spyOn(auth, 'clearLocalSession');

    vi.spyOn(globalThis, 'fetch').mockResolvedValue(
      new Response(
        JSON.stringify({
          detail: 'Token is expired',
          code: 'token_not_valid',
        }),
        { status: 401, statusText: 'Unauthorized' },
      ),
    );

    const promise = firstValueFrom(http.get('/api/v1/services/'));
    const first = controller.expectOne('/api/v1/services/');
    expect(first.request.headers.get('Authorization')).toBe('Bearer old');
    first.flush(
      { detail: 'Given token not valid for any token type', code: 'token_not_valid' },
      { status: 401, statusText: 'Unauthorized' },
    );

    const retry = await vi.waitFor(() => {
      const match = controller.match('/api/v1/services/');
      expect(match.length).toBe(1);
      return match[0]!;
    });

    expect(retry.request.headers.get('Authorization')).toBeNull();
    expect(retry.request.headers.get('X-Auth-Retry')).toBe('1');
    retry.flush([{ id: 'svc-1' }]);

    await expect(promise).resolves.toEqual([{ id: 'svc-1' }]);
    expect(clearSpy).toHaveBeenCalled();
    expect(storage.getAccessToken()).toBeNull();
    expect(storage.getRefreshToken()).toBeNull();
    expect(auth.currentUser()).toBeNull();
  });

  it('soft-clears and retries anonymously when there is no refresh token', async () => {
    localStorage.setItem('access_token', 'old');
    localStorage.removeItem('refresh_token');

    const promise = firstValueFrom(http.get('/api/v1/services/'));
    const first = controller.expectOne('/api/v1/services/');
    first.flush({ code: 'token_not_valid' }, { status: 401, statusText: 'Unauthorized' });

    const retry = await vi.waitFor(() => {
      const match = controller.match('/api/v1/services/');
      expect(match.length).toBe(1);
      return match[0]!;
    });

    expect(retry.request.headers.get('Authorization')).toBeNull();
    retry.flush([]);
    await expect(promise).resolves.toEqual([]);
    expect(storage.hasAccessToken()).toBe(false);
  });
});
