import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';

import { AuthService } from './auth.service';
import { TokenStorageService } from './token-storage.service';

describe('AuthService', () => {
  let service: AuthService;
  let http: HttpTestingController;
  let storage: TokenStorageService;

  beforeEach(() => {
    localStorage.clear();
    TestBed.configureTestingModule({
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    service = TestBed.inject(AuthService);
    http = TestBed.inject(HttpTestingController);
    storage = TestBed.inject(TokenStorageService);
  });

  afterEach(() => {
    http.verify();
    localStorage.clear();
  });

  it('logs in and persists session', async () => {
    const promise = service.login({
      email: 'a@b.com',
      password: 'secret',
      turnstileToken: 'tok',
    });
    const req = http.expectOne((r) => r.url.includes('auth/login/') && r.method === 'POST');
    expect(req.request.body['cf_turnstile_response']).toBe('tok');
    req.flush({
      access: 'acc',
      refresh: 'ref',
      user: { id: '9', email: 'a@b.com', first_name: 'Ada', two_factor_enabled: false },
    });

    const result = await promise;
    expect('requiresOtp' in result).toBe(false);
    if ('requiresOtp' in result) {
      return;
    }
    expect(result.email).toBe('a@b.com');
    expect(storage.getAccessToken()).toBe('acc');
    expect(service.currentUser()?.id).toBe('9');
  });

  it('returns otp challenge when login requires 2FA', async () => {
    const promise = service.login({
      email: 'a@b.com',
      password: 'secret',
      turnstileToken: 'tok',
    });
    const req = http.expectOne((r) => r.url.includes('auth/login/') && r.method === 'POST');
    req.flush({
      requires_otp: true,
      challenge_id: 'ch-1',
      email_hint: 'a@b.com',
    });
    const result = await promise;
    expect(result).toEqual({
      requiresOtp: true,
      challengeId: 'ch-1',
      emailHint: 'a@b.com',
    });
    expect(storage.getAccessToken()).toBeNull();
  });

  it('updates profile', async () => {
    storage.saveTokens('acc', 'ref');
    const promise = service.updateProfile({ first_name: 'Grace' });
    const req = http.expectOne((r) => r.url.includes('auth/profile/') && r.method === 'PUT');
    req.flush({ id: '1', email: 'g@b.com', first_name: 'Grace' });
    const user = await promise;
    expect(user.firstName).toBe('Grace');
  });

  it('clears session on logout even if API fails', async () => {
    storage.saveTokens('acc', 'ref');
    storage.saveUser({
      id: '1',
      email: 'a@b.com',
      username: null,
      firstName: null,
      lastName: null,
      phone: null,
      role: null,
      organization: null,
      organizationName: null,
      organizationMemberships: [],
      trustAlias: null,
      avatarUrl: null,
      showRealName: false,
      showPhoneNumber: false,
      showEmail: false,
      dateOfBirth: null,
      sex: null,
      age: null,
      verificationStatus: null,
      verificationRejectionReason: null,
      verifiedAt: null,
      twoFactorEnabled: true,
      isStaff: false,
      legal: null,
    });

    const promise = service.logout();
    const req = http.expectOne((r) => r.url.includes('auth/logout/'));
    req.flush({ detail: 'nope' }, { status: 400, statusText: 'Bad Request' });
    await promise;

    expect(storage.hasAccessToken()).toBe(false);
    expect(service.currentUser()).toBeNull();
  });
});
