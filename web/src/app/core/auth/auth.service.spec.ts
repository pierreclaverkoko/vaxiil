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

  it('creates a Sumsub WebSDK link', async () => {
    storage.saveTokens('acc', 'ref');
    const promise = service.createSumsubWebsdkLink({ lang: 'fr' });
    const req = http.expectOne(
      (r) => r.url.includes('auth/kyc/sumsub/websdk-link/') && r.method === 'POST',
    );
    expect(req.request.body['lang']).toBe('fr');
    req.flush({ url: 'https://api.sumsub.com/idensic/l/#/x' });
    await expect(promise).resolves.toBe('https://api.sumsub.com/idensic/l/#/x');
  });

  it('completes Sumsub return and updates the user', async () => {
    storage.saveTokens('acc', 'ref');
    const promise = service.completeSumsubReturn({
      jwt: 'tok.jwt.here',
      status: 'ok',
      sbx: 'true',
    });
    const req = http.expectOne(
      (r) => r.url.includes('auth/kyc/sumsub/return/') && r.method === 'POST',
    );
    expect(req.request.body).toEqual({
      jwt: 'tok.jwt.here',
      status: 'ok',
      sbx: true,
    });
    req.flush({
      id: '1',
      email: 'a@b.com',
      verification_status: { value: 'V', title: 'Verified', css: 'success' },
    });
    const user = await promise;
    expect(user.verificationStatus?.value).toBe('V');
    expect(service.currentUser()?.verificationStatus?.value).toBe('V');
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
      idDocumentUrl: null,
      selfieDocumentUrl: null,
      twoFactorEnabled: true,
      emailVerified: true,
      needsEmailVerification: false,
      defaultCountryId: null,
      defaultCountryName: null,
      isStaff: false,
      isSuperuser: false,
      legal: null,
    });

    const promise = service.logout();
    const req = http.expectOne((r) => r.url.includes('auth/logout/'));
    req.flush({ detail: 'nope' }, { status: 400, statusText: 'Bad Request' });
    await promise;

    expect(storage.hasAccessToken()).toBe(false);
    expect(service.currentUser()).toBeNull();
  });

  it('sends email verification with optional force and normalizes code', async () => {
    storage.saveTokens('acc', 'ref');
    const softPromise = service.sendEmailVerification();
    const softReq = http.expectOne(
      (r) => r.url.includes('auth/email/verify/send/') && r.method === 'POST',
    );
    expect(softReq.request.body).toEqual({});
    softReq.flush({
      challenge_id: 'ch-soft',
      email_hint: 'a@b.com',
      resent: false,
    });
    expect(await softPromise).toEqual({
      challengeId: 'ch-soft',
      emailHint: 'a@b.com',
      resent: false,
    });

    const forcePromise = service.sendEmailVerification({ force: true });
    const forceReq = http.expectOne(
      (r) => r.url.includes('auth/email/verify/send/') && r.method === 'POST',
    );
    expect(forceReq.request.body).toEqual({ force: true });
    forceReq.flush({
      challenge_id: 'ch-force',
      email_hint: 'a@b.com',
      resent: true,
    });
    expect(await forcePromise).toEqual({
      challengeId: 'ch-force',
      emailHint: 'a@b.com',
      resent: true,
    });

    const verifyPromise = service.verifyEmail('ch-force', '1 2 3 4 5 6');
    const verifyReq = http.expectOne(
      (r) => r.url.includes('auth/email/verify/') && !r.url.includes('send') && r.method === 'POST',
    );
    expect(verifyReq.request.body).toEqual({
      challenge_id: 'ch-force',
      code: '123456',
    });
    verifyReq.flush({
      id: '1',
      email: 'a@b.com',
      email_verified: true,
      needs_email_verification: false,
    });
    const user = await verifyPromise;
    expect(user.needsEmailVerification).toBe(false);
  });
});
