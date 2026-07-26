import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';

import { AuthService } from '@/core/auth/auth.service';
import { ApiError } from '@/core/http/api-error';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { OrganizationsService } from '@/features/business/organizations.service';
import { AuthUser } from '@/models/auth-user';
import { CountryBrief } from '@/models/organization';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';
import { InputComponent } from '@/shared/ui/input/input';

@Component({
  selector: 'app-personal-info-page',
  standalone: true,
  imports: [
    FormsModule,
    ButtonComponent,
    ErrorStateComponent,
    InputComponent,
    TranslatePipe,
  ],
  templateUrl: './personal-info-page.html',
  styleUrl: './personal-info-page.scss',
})
export class PersonalInfoPageComponent implements OnInit {
  private readonly auth = inject(AuthService);
  private readonly orgsApi = inject(OrganizationsService);
  private readonly locale = inject(LocaleService);

  protected readonly editing = signal(false);
  protected readonly profile = signal<AuthUser | null>(null);
  protected readonly firstName = signal('');
  protected readonly lastName = signal('');
  protected readonly phone = signal('');
  protected readonly dateOfBirth = signal('');
  protected readonly sex = signal('');
  protected readonly defaultCountryId = signal('');
  protected readonly countries = signal<CountryBrief[]>([]);
  protected readonly saving = signal(false);
  protected readonly formError = signal<string | null>(null);
  protected readonly loadError = signal<string | null>(null);

  protected readonly displayName = computed(() => {
    const u = this.profile();
    if (!u) {
      return '—';
    }
    const parts = [u.firstName, u.lastName].filter((p) => p && p.trim());
    return parts.length ? parts.join(' ') : '—';
  });

  protected readonly displaySex = computed(() => {
    this.locale.locale();
    const u = this.profile();
    if (u?.sex?.title) {
      return u.sex.title;
    }
    const code = u?.sex?.value != null ? String(u.sex.value) : '';
    return this.sexLabel(code);
  });

  protected readonly displayCountry = computed(() => {
    const u = this.profile();
    if (u?.defaultCountryName) {
      return u.defaultCountryName;
    }
    const id = u?.defaultCountryId;
    if (!id) {
      return this.locale.t('profile.defaultCountryUnset');
    }
    return this.countries().find((c) => c.id === id)?.name ?? this.locale.t('profile.defaultCountryUnset');
  });

  protected readonly displayDob = computed(() => {
    const raw = this.profile()?.dateOfBirth;
    if (!raw) {
      return '—';
    }
    return raw;
  });

  protected readonly displayPhone = computed(() => {
    const phone = this.profile()?.phone?.trim();
    return phone || '—';
  });

  async ngOnInit(): Promise<void> {
    try {
      const [profile, countries] = await Promise.all([
        this.auth.fetchProfile(),
        this.orgsApi.listCountries(),
      ]);
      this.countries.set(countries);
      this.profile.set(profile);
      this.hydrate(profile);
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    }
  }

  protected startEdit(): void {
    const user = this.profile();
    if (user) {
      this.hydrate(user);
    }
    this.formError.set(null);
    this.editing.set(true);
  }

  protected cancelEdit(): void {
    const user = this.profile();
    if (user) {
      this.hydrate(user);
    }
    this.formError.set(null);
    this.editing.set(false);
  }

  protected async onSave(event: Event): Promise<void> {
    event.preventDefault();
    if (this.saving()) {
      return;
    }
    this.formError.set(null);
    this.saving.set(true);
    try {
      const updated = await this.auth.updateProfile({
        first_name: this.firstName().trim(),
        last_name: this.lastName().trim(),
        phone: this.phone().trim(),
        date_of_birth: this.dateOfBirth().trim() || null,
        sex: this.sex().trim() || null,
        default_country_id: this.defaultCountryId().trim() || null,
      });
      this.profile.set(updated);
      this.hydrate(updated);
      this.editing.set(false);
    } catch (error) {
      this.formError.set((error as ApiError).message);
    } finally {
      this.saving.set(false);
    }
  }

  private hydrate(user: AuthUser): void {
    this.firstName.set(user.firstName ?? '');
    this.lastName.set(user.lastName ?? '');
    this.phone.set(user.phone ?? '');
    this.dateOfBirth.set(user.dateOfBirth ?? '');
    this.sex.set(user.sex?.value != null ? String(user.sex.value) : '');
    this.defaultCountryId.set(user.defaultCountryId ?? '');
  }

  private sexLabel(code: string): string {
    switch (code) {
      case 'F':
        return this.locale.t('profile.sexFemale');
      case 'M':
        return this.locale.t('profile.sexMale');
      case 'X':
        return this.locale.t('profile.sexOther');
      case 'U':
        return this.locale.t('profile.sexPreferNot');
      default:
        return this.locale.t('profile.sexUnset');
    }
  }
}
