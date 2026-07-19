import { TestBed } from '@angular/core/testing';
import { Router } from '@angular/router';
import { describe, expect, it, vi } from 'vitest';

import { AuthService } from '@/core/auth/auth.service';
import { TokenStorageService } from '@/core/auth/token-storage.service';
import { AuthUser } from '@/models/auth-user';

import { staffGuard } from './auth.guards';

describe('staffGuard', () => {
  const staffUser = {
    id: '1',
    email: 's@example.com',
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
    legal: null,

    isStaff: true,
  } satisfies AuthUser;

  it('allows staff users', async () => {
    TestBed.configureTestingModule({
      providers: [
        {
          provide: AuthService,
          useValue: {
            currentUser: () => staffUser,
            restoreSession: vi.fn(),
          },
        },
        {
          provide: TokenStorageService,
          useValue: { hasAccessToken: () => true },
        },
        {
          provide: Router,
          useValue: { createUrlTree: vi.fn((commands: string[]) => commands) },
        },
      ],
    });
    const result = await TestBed.runInInjectionContext(() =>
      staffGuard({} as never, { url: '/staff' } as never),
    );
    expect(result).toBe(true);
  });

  it('redirects non-staff to discover', async () => {
    const createUrlTree = vi.fn((commands: string[]) => commands);
    TestBed.configureTestingModule({
      providers: [
        {
          provide: AuthService,
          useValue: {
            currentUser: () => ({ ...staffUser, isStaff: false }),
            restoreSession: vi.fn(),
          },
        },
        {
          provide: TokenStorageService,
          useValue: { hasAccessToken: () => true },
        },
        { provide: Router, useValue: { createUrlTree } },
      ],
    });
    const result = await TestBed.runInInjectionContext(() =>
      staffGuard({} as never, { url: '/staff' } as never),
    );
    expect(createUrlTree).toHaveBeenCalledWith(['/discover']);
    expect(result).toEqual(['/discover']);
  });
});
