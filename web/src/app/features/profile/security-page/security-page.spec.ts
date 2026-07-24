import { TestBed } from '@angular/core/testing';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { AuthService } from '@/core/auth/auth.service';
import { LocaleService } from '@/core/i18n/locale.service';

import { SecurityPageComponent } from './security-page';

describe('SecurityPageComponent', () => {
  const updateProfile = vi.fn();
  const currentUser = vi.fn(() => ({ twoFactorEnabled: true }));

  beforeEach(() => {
    updateProfile.mockReset();
    currentUser.mockReturnValue({ twoFactorEnabled: true });
    vi.stubGlobal('confirm', vi.fn(() => true));
    TestBed.configureTestingModule({
      imports: [SecurityPageComponent],
      providers: [
        {
          provide: AuthService,
          useValue: {
            currentUser,
            updateProfile,
            sendOtp: vi.fn(),
            changePassword: vi.fn(),
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
    });
  });

  it('disables two-factor via profile update', async () => {
    updateProfile.mockResolvedValue({ twoFactorEnabled: false });
    const fixture = TestBed.createComponent(SecurityPageComponent);
    fixture.detectChanges();
    const component = fixture.componentInstance as unknown as {
      onToggleTwoFactor: (v: boolean) => Promise<void>;
      twoFactorEnabled: () => boolean;
    };
    await component.onToggleTwoFactor(false);
    expect(updateProfile).toHaveBeenCalledWith({ two_factor_enabled: false });
    expect(component.twoFactorEnabled()).toBe(false);
  });
});
