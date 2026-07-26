import { Component } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { provideRouter, Router, RouterOutlet } from '@angular/router';
import { describe, expect, it, vi } from 'vitest';

import { AuthService } from '@/core/auth/auth.service';
import { TokenStorageService } from '@/core/auth/token-storage.service';

import { routes } from './app.routes';

@Component({
  selector: 'app-root-host',
  template: '<router-outlet />',
  standalone: true,
  imports: [RouterOutlet],
})
class RootHostComponent {}

describe('app routes root redirect', () => {
  it('redirects / to /onboarding for guests', async () => {
    TestBed.configureTestingModule({
      imports: [RootHostComponent],
      providers: [
        provideRouter(routes),
        {
          provide: AuthService,
          useValue: {
            currentUser: () => null,
            restoreSession: vi.fn().mockResolvedValue(null),
            isAuthenticated: () => false,
          },
        },
        {
          provide: TokenStorageService,
          useValue: { hasAccessToken: () => false },
        },
      ],
    });
    TestBed.createComponent(RootHostComponent);
    const router = TestBed.inject(Router);
    await router.navigateByUrl('/');
    expect(router.url).toBe('/onboarding');
  });

  it('redirects / through onboarding to /discover when authenticated', async () => {
    const user = {
      id: '1',
      email: 'u@example.com',
      needsEmailVerification: false,
      legal: { needsAcceptance: false },
      isStaff: false,
    };
    TestBed.configureTestingModule({
      imports: [RootHostComponent],
      providers: [
        provideRouter(routes),
        {
          provide: AuthService,
          useValue: {
            currentUser: () => user,
            restoreSession: vi.fn().mockResolvedValue(user),
            isAuthenticated: () => true,
          },
        },
        {
          provide: TokenStorageService,
          useValue: { hasAccessToken: () => true },
        },
      ],
    });
    TestBed.createComponent(RootHostComponent);
    const router = TestBed.inject(Router);
    await router.navigateByUrl('/');
    expect(router.url).toBe('/discover');
  });
});
