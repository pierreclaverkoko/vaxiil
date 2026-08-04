import { signal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { AuthService } from '@/core/auth/auth.service';
import { LocaleService } from '@/core/i18n/locale.service';
import { NotificationsService } from '@/features/notifications/notifications.service';
import { AuthUser } from '@/models/auth-user';

import { ConsumerAppShellComponent } from './consumer-app-shell';

function makeUser(isStaff: boolean): AuthUser {
  return {
    id: 'u1',
    email: 'a@b.com',
    username: null,
    firstName: 'A',
    lastName: 'B',
    phone: null,
    role: null,
    organization: null,
    organizationName: null,
    organizationMemberships: [],
    trustAlias: null,
    avatarUrl: null,
    showRealName: true,
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
    isStaff,
    isSuperuser: false,
    legal: null,
  };
}

describe('ConsumerAppShellComponent', () => {
  let fixture: ComponentFixture<ConsumerAppShellComponent>;
  const userSignal = signal<AuthUser | null>(makeUser(false));

  beforeEach(async () => {
    userSignal.set(makeUser(false));
    await TestBed.configureTestingModule({
      imports: [ConsumerAppShellComponent],
      providers: [
        provideRouter([]),
        {
          provide: AuthService,
          useValue: {
            isAuthenticated: signal(true).asReadonly(),
            currentUser: userSignal.asReadonly(),
            logout: vi.fn().mockResolvedValue(undefined),
          },
        },
        {
          provide: LocaleService,
          useValue: {
            t: (key: string) => key,
            locale: () => 'en',
          },
        },
        {
          provide: NotificationsService,
          useValue: {
            unreadCount: vi.fn().mockResolvedValue(0),
          },
        },
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(ConsumerAppShellComponent);
    fixture.detectChanges();
  });

  it('shows Business link but not Staff when user is not staff', () => {
    const el: HTMLElement = fixture.nativeElement;
    expect(el.querySelector('a[href="/business"]')).toBeTruthy();
    expect(el.querySelector('a[href="/staff"]')).toBeNull();
  });

  it('keeps Profile in the account menu but not primary / bottom nav', () => {
    const el: HTMLElement = fixture.nativeElement;
    const bottom = el.querySelector('.consumer-shell__bottom');
    expect(bottom?.querySelector('a[href="/profile"]')).toBeNull();
    expect(el.querySelector('.consumer-shell__nav a[href="/profile"]')).toBeNull();

    const avatar = el.querySelector('.consumer-shell__avatar-btn') as HTMLButtonElement;
    avatar.click();
    fixture.detectChanges();
    expect(el.querySelector('.consumer-shell__menu a[href="/profile"]')).toBeTruthy();
    expect(el.querySelector('.consumer-shell__menu a[href="/profile/transactions"]')).toBeTruthy();
  });

  it('shows Staff link when user is staff', () => {
    userSignal.set(makeUser(true));
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('a[href="/staff"]')).toBeTruthy();
  });
});
