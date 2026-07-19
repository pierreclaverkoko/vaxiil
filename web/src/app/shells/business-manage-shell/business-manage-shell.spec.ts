import { signal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { AuthService } from '@/core/auth/auth.service';
import { LocaleService } from '@/core/i18n/locale.service';
import { OrganizationContextService } from '@/features/business/organization-context.service';
import { AuthUser } from '@/models/auth-user';

import { BusinessManageShellComponent } from './business-manage-shell';

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
    twoFactorEnabled: true,
    isStaff,
    legal: null,
  };
}

describe('BusinessManageShellComponent', () => {
  let fixture: ComponentFixture<BusinessManageShellComponent>;
  const userSignal = signal<AuthUser | null>(makeUser(false));

  beforeEach(async () => {
    userSignal.set(makeUser(false));
    await TestBed.configureTestingModule({
      imports: [BusinessManageShellComponent],
      providers: [
        provideRouter([]),
        {
          provide: AuthService,
          useValue: {
            currentUser: userSignal.asReadonly(),
            logout: vi.fn().mockResolvedValue(undefined),
          },
        },
        {
          provide: OrganizationContextService,
          useValue: {
            organizations: signal([]).asReadonly(),
            currentOrg: signal(null).asReadonly(),
            currentOrgId: signal(null).asReadonly(),
            refresh: vi.fn().mockResolvedValue([]),
            setCurrentOrgId: vi.fn(),
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

    fixture = TestBed.createComponent(BusinessManageShellComponent);
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();
  });

  it('renders Back to app pill in the toolbar', () => {
    const el: HTMLElement = fixture.nativeElement;
    const back = el.querySelector('.biz-shell__toolbar-actions .biz-shell__pill');
    expect(back?.getAttribute('href') ?? back?.getAttribute('ng-reflect-router-link')).toBeTruthy();
    expect(el.querySelector('.biz-shell__toolbar')?.textContent).toContain('common.backToApp');
    expect(el.querySelector('.biz-shell__footer')?.textContent).not.toContain('common.backToApp');
  });

  it('hides Staff pill when user is not staff', () => {
    const el: HTMLElement = fixture.nativeElement;
    const pills = Array.from(el.querySelectorAll('.biz-shell__pill')).map((n) =>
      n.textContent?.trim(),
    );
    expect(pills).not.toContain('shell.staff.badge');
  });

  it('shows Staff pill when user is staff', () => {
    userSignal.set(makeUser(true));
    fixture.detectChanges();
    const el: HTMLElement = fixture.nativeElement;
    expect(el.querySelector('.biz-shell__toolbar-actions')?.textContent).toContain(
      'shell.staff.badge',
    );
  });
});
