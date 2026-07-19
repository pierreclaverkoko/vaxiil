import { signal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { AuthService } from '@/core/auth/auth.service';
import { LocaleService } from '@/core/i18n/locale.service';
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
    isStaff,
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
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(ConsumerAppShellComponent);
    fixture.detectChanges();
  });

  it('shows Business link but not Staff when user is not staff', () => {
    const el: HTMLElement = fixture.nativeElement;
    expect(el.textContent).toContain('common.business');
    expect(el.textContent).not.toContain('shell.staff.badge');
  });

  it('shows Staff link when user is staff', () => {
    userSignal.set(makeUser(true));
    fixture.detectChanges();
    expect(fixture.nativeElement.textContent).toContain('shell.staff.badge');
  });
});
