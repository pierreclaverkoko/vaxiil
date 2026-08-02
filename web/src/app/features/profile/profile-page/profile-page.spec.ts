import { signal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { AuthService } from '@/core/auth/auth.service';
import { LocaleService } from '@/core/i18n/locale.service';
import { PaymentsService } from '@/features/bookings/payments.service';
import { clearKycSubmitted, markKycSubmitted } from '@/features/profile/kyc-session';
import { AuthUser } from '@/models/auth-user';

import { ProfilePageComponent } from './profile-page';

function makeUser(overrides: Partial<AuthUser> = {}): AuthUser {
  return {
    id: 'u1',
    email: 'julian@example.com',
    username: null,
    firstName: 'Julian',
    lastName: 'Thorne',
    phone: null,
    role: null,
    organization: null,
    organizationName: null,
    organizationMemberships: [],
    trustAlias: 'Quiet Fern',
    avatarUrl: null,
    showRealName: false,
    showPhoneNumber: false,
    showEmail: false,
    dateOfBirth: null,
    sex: null,
    age: null,
    verificationStatus: { value: 'P', title: 'Pending Verification', css: 'warning' },
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
    ...overrides,
  };
}

describe('ProfilePageComponent', () => {
  let fixture: ComponentFixture<ProfilePageComponent>;
  let userSignal: ReturnType<typeof signal<AuthUser | null>>;

  async function setup(user: AuthUser): Promise<void> {
    userSignal = signal<AuthUser | null>(user);
    await TestBed.configureTestingModule({
      imports: [ProfilePageComponent],
      providers: [
        provideRouter([]),
        {
          provide: AuthService,
          useValue: {
            currentUser: userSignal,
            fetchProfile: vi.fn().mockResolvedValue(user),
            updateProfile: vi.fn().mockResolvedValue(user),
            uploadAvatar: vi.fn(),
            logout: vi.fn().mockResolvedValue(undefined),
          },
        },
        {
          provide: LocaleService,
          useValue: {
            t: (key: string, params?: Record<string, string>) =>
              params?.['date'] ? `${key}:${params['date']}` : key,
            locale: () => 'en',
          },
        },
        {
          provide: PaymentsService,
          useValue: {
            getWallet: vi.fn().mockResolvedValue({ balances: [], totalCredited: '0' }),
          },
        },
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(ProfilePageComponent);
    fixture.detectChanges();
    await Promise.resolve();
    fixture.detectChanges();
  }

  beforeEach(() => {
    TestBed.resetTestingModule();
    clearKycSubmitted();
  });

  it('shows not-verified KYC card for pending users', async () => {
    clearKycSubmitted();
    await setup(makeUser());
    const el: HTMLElement = fixture.nativeElement;
    expect(el.querySelector('.profile__kyc-card')?.getAttribute('data-state')).toBe(
      'not_verified',
    );
    expect(el.textContent).toContain('profile.kycNotVerified');
    expect(el.textContent).toContain('profile.kycCta');
    expect(el.querySelector('.profile__business-cta')).toBeTruthy();
  });

  it('shows in-review KYC card after session submit', async () => {
    markKycSubmitted();
    await setup(makeUser());
    const el: HTMLElement = fixture.nativeElement;
    expect(el.querySelector('.profile__kyc-card')?.getAttribute('data-state')).toBe('in_review');
    expect(el.textContent).toContain('profile.kycInReview');
  });

  it('shows verified KYC card', async () => {
    await setup(
      makeUser({
        verificationStatus: { value: 'V', title: 'Verified', css: 'success' },
        verifiedAt: '2023-10-24T00:00:00Z',
      }),
    );
    const el: HTMLElement = fixture.nativeElement;
    expect(el.querySelector('.profile__kyc-card')?.getAttribute('data-state')).toBe('verified');
    expect(el.textContent).toContain('profile.kycVerifiedLabel');
    expect(el.querySelector('.profile__verified-icon')).toBeTruthy();
  });
});
