import { ComponentFixture, TestBed } from '@angular/core/testing';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { AuthService } from '@/core/auth/auth.service';
import { LocaleService } from '@/core/i18n/locale.service';
import { OrganizationsService } from '@/features/business/organizations.service';
import { AuthUser } from '@/models/auth-user';

import { PersonalInfoPageComponent } from './personal-info-page';

function makeUser(overrides: Partial<AuthUser> = {}): AuthUser {
  return {
    id: 'u1',
    email: 'julian@example.com',
    username: null,
    firstName: 'Julian',
    lastName: 'Thorne',
    phone: '+123',
    role: null,
    organization: null,
    organizationName: null,
    organizationMemberships: [],
    trustAlias: null,
    avatarUrl: null,
    showRealName: false,
    showPhoneNumber: false,
    showEmail: false,
    dateOfBirth: '1990-01-15',
    sex: { value: 'F', title: 'Female', css: 'default' },
    age: null,
    verificationStatus: null,
    verificationRejectionReason: null,
    verifiedAt: null,
    idDocumentUrl: null,
    selfieDocumentUrl: null,
    twoFactorEnabled: true,
    emailVerified: true,
    needsEmailVerification: false,
    defaultCountryId: 'c1',
    defaultCountryName: 'United Kingdom',
    isStaff: false,
    isSuperuser: false,
    legal: null,
    ...overrides,
  };
}

describe('PersonalInfoPageComponent', () => {
  let fixture: ComponentFixture<PersonalInfoPageComponent>;
  let updateProfile: ReturnType<typeof vi.fn>;
  let fetchProfile: ReturnType<typeof vi.fn>;

  beforeEach(async () => {
    const user = makeUser();
    fetchProfile = vi.fn().mockResolvedValue(user);
    updateProfile = vi.fn().mockResolvedValue(
      makeUser({
        firstName: 'Jules',
        sex: { value: 'M', title: 'Male', css: 'default' },
      }),
    );
    await TestBed.configureTestingModule({
      imports: [PersonalInfoPageComponent],
      providers: [
        {
          provide: AuthService,
          useValue: {
            fetchProfile,
            updateProfile,
            currentUser: () => user,
          },
        },
        {
          provide: OrganizationsService,
          useValue: {
            listCountries: vi.fn().mockResolvedValue([
              {
                id: 'c1',
                isoCode2: 'GB',
                name: 'United Kingdom',
                flag: null,
                phoneCode: '44',
              },
              {
                id: 'c2',
                isoCode2: 'US',
                name: 'United States',
                flag: null,
                phoneCode: '1',
              },
            ]),
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

    fixture = TestBed.createComponent(PersonalInfoPageComponent);
    await fixture.componentInstance.ngOnInit();
    fixture.detectChanges();
  });

  it('loads profile via fetchProfile and shows view mode', () => {
    expect(fetchProfile).toHaveBeenCalled();
    const el = fixture.nativeElement as HTMLElement;
    expect(el.textContent).toContain('Julian Thorne');
    expect(el.textContent).toContain('Female');
    expect(el.textContent).toContain('United Kingdom');
    expect(el.querySelector('form')).toBeNull();
    expect(el.textContent).toContain('profile.modify');
  });

  it('enters edit mode with prefilled values', async () => {
    const el = fixture.nativeElement as HTMLElement;
    const modifyBtn = Array.from(el.querySelectorAll('button')).find((b) =>
      b.textContent?.includes('profile.modify'),
    );
    modifyBtn?.click();
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();
    expect(el.querySelector('form')).not.toBeNull();
    const sex = el.querySelector('#personal-sex') as HTMLSelectElement;
    const country = el.querySelector('#personal-country') as HTMLSelectElement;
    expect(sex.value).toBe('F');
    expect(country.value).toBe('c1');
    const page = fixture.componentInstance as unknown as {
      defaultCountryId: () => string;
      sex: () => string;
    };
    expect(page.sex()).toBe('F');
    expect(page.defaultCountryId()).toBe('c1');
  });

  it('saves and returns to view mode', async () => {
    const el = fixture.nativeElement as HTMLElement;
    Array.from(el.querySelectorAll('button'))
      .find((b) => b.textContent?.includes('profile.modify'))
      ?.click();
    fixture.detectChanges();

    // Model signals are protected; update via component instance cast for the test.
    const page = fixture.componentInstance as unknown as {
      firstName: { set: (v: string) => void };
      sex: { set: (v: string) => void };
    };
    page.firstName.set('Jules');
    page.sex.set('M');
    fixture.detectChanges();

    const form = el.querySelector('form') as HTMLFormElement;
    form.dispatchEvent(new Event('submit'));
    await fixture.whenStable();
    fixture.detectChanges();

    expect(updateProfile).toHaveBeenCalledWith(
      expect.objectContaining({
        first_name: 'Jules',
        sex: 'M',
        default_country_id: 'c1',
      }),
    );
    expect(el.querySelector('form')).toBeNull();
    expect(el.textContent).toContain('Jules');
    expect(el.textContent).toContain('Male');
  });

  it('cancel returns to view without saving', () => {
    const el = fixture.nativeElement as HTMLElement;
    Array.from(el.querySelectorAll('button'))
      .find((b) => b.textContent?.includes('profile.modify'))
      ?.click();
    fixture.detectChanges();

    Array.from(el.querySelectorAll('button'))
      .find((b) => b.textContent?.includes('common.cancel'))
      ?.click();
    fixture.detectChanges();

    expect(updateProfile).not.toHaveBeenCalled();
    expect(el.querySelector('form')).toBeNull();
    expect(el.textContent).toContain('Julian Thorne');
  });
});
