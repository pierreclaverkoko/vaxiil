import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter, Router } from '@angular/router';
import { signal } from '@angular/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { AuthService } from '@/core/auth/auth.service';
import { LocaleService } from '@/core/i18n/locale.service';
import { AuthUser } from '@/models/auth-user';

import { KycVerifyPageComponent } from './kyc-verify-page';

describe('KycVerifyPageComponent', () => {
  let fixture: ComponentFixture<KycVerifyPageComponent>;
  let createSumsubWebsdkLink: ReturnType<typeof vi.fn>;
  let completeSumsubReturn: ReturnType<typeof vi.fn>;
  let fetchProfile: ReturnType<typeof vi.fn>;
  const userSignal = signal<AuthUser | null>(null);

  const baseUser: AuthUser = {
    id: 'u1',
    email: 'a@b.c',
    username: 'a',
    firstName: null,
    lastName: null,
    phone: null,
    role: { value: 'C', title: 'Client', css: 'secondary' },
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
    verificationStatus: { value: 'P', title: 'Pending', css: 'warning' },
    verificationRejectionReason: null,
    verifiedAt: null,
    idDocumentUrl: null,
    selfieDocumentUrl: null,
    isStaff: false,
    isSuperuser: false,
    twoFactorEnabled: false,
    emailVerified: true,
    needsEmailVerification: false,
    defaultCountryId: null,
    defaultCountryName: null,
    legal: null,
  };

  beforeEach(async () => {
    createSumsubWebsdkLink = vi.fn().mockResolvedValue('https://sumsub.example/link');
    completeSumsubReturn = vi.fn().mockResolvedValue(baseUser);
    fetchProfile = vi.fn().mockResolvedValue(baseUser);
    userSignal.set({ ...baseUser });
    await TestBed.configureTestingModule({
      imports: [KycVerifyPageComponent],
      providers: [
        provideRouter([]),
        {
          provide: AuthService,
          useValue: {
            currentUser: userSignal.asReadonly(),
            fetchProfile,
            createSumsubWebsdkLink,
            completeSumsubReturn,
          },
        },
        {
          provide: LocaleService,
          useValue: {
            locale: signal('en'),
            t: (k: string) => k,
          },
        },
      ],
    }).compileComponents();
    fixture = TestBed.createComponent(KycVerifyPageComponent);
    fixture.detectChanges();
  });

  it('requests a Sumsub WebSDK link on start', async () => {
    const assign = vi.fn();
    Object.defineProperty(window, 'location', {
      configurable: true,
      value: {
        assign,
        origin: 'http://localhost:4200',
        href: 'http://localhost:4200/profile/verify',
      },
    });
    await fixture.componentInstance['onStartVerification']();
    expect(createSumsubWebsdkLink).toHaveBeenCalledWith(
      expect.objectContaining({
        successUrl: expect.stringContaining('/profile/verify/return?status=ok'),
        rejectUrl: expect.stringContaining('/profile/verify/return?status=reject'),
      }),
    );
    expect(assign).toHaveBeenCalledWith('https://sumsub.example/link');
  });

  it('posts Sumsub return JWT then uses updated verification status', async () => {
    const verified = {
      ...baseUser,
      verificationStatus: { value: 'V', title: 'Verified', css: 'success' },
    };
    completeSumsubReturn.mockImplementation(async () => {
      userSignal.set(verified);
      return verified;
    });
    const router = TestBed.inject(Router);
    vi.spyOn(router, 'url', 'get').mockReturnValue(
      '/profile/verify/return?status=ok&jwt=abc.def.ghi&sbx=true',
    );
    Object.defineProperty(fixture.componentInstance['route'].snapshot, 'queryParamMap', {
      configurable: true,
      get: () => ({
        get: (key: string) =>
          ({ status: 'ok', jwt: 'abc.def.ghi', sbx: 'true' })[key] ?? null,
      }),
    });
    await fixture.componentInstance.ngOnInit();
    expect(completeSumsubReturn).toHaveBeenCalledWith({
      jwt: 'abc.def.ghi',
      status: 'ok',
      sbx: 'true',
    });
    expect(fixture.componentInstance['formSuccess']()).toBe('profile.kycReturnOk');
  });

  it('clears submitted flag and re-opens WebSDK when redirect JWT expired', async () => {
    const { markKycSubmitted, wasKycSubmittedThisSession } = await import(
      '@/features/profile/kyc-session'
    );
    markKycSubmitted();
    expect(wasKycSubmittedThisSession()).toBe(true);

    completeSumsubReturn.mockRejectedValue({
      message: 'Sumsub redirect JWT has expired.',
      status: 400,
      fieldErrors: {},
      code: 'sumsub_redirect_jwt_expired',
    });
    const assign = vi.fn();
    Object.defineProperty(window, 'location', {
      configurable: true,
      value: {
        assign,
        origin: 'http://localhost:4200',
        href: 'http://localhost:4200/profile/verify/return?jwt=expired',
      },
    });
    const router = TestBed.inject(Router);
    vi.spyOn(router, 'url', 'get').mockReturnValue(
      '/profile/verify/return?status=ok&jwt=expired.token.here',
    );
    Object.defineProperty(fixture.componentInstance['route'].snapshot, 'queryParamMap', {
      configurable: true,
      get: () => ({
        get: (key: string) =>
          ({ status: 'ok', jwt: 'expired.token.here', sbx: null })[key] ?? null,
      }),
    });

    await fixture.componentInstance.ngOnInit();

    expect(completeSumsubReturn).toHaveBeenCalled();
    expect(createSumsubWebsdkLink).toHaveBeenCalled();
    expect(assign).toHaveBeenCalledWith('https://sumsub.example/link');
    expect(wasKycSubmittedThisSession()).toBe(true);
    expect(fixture.componentInstance['formSuccess']()).toBeNull();
  });
});
