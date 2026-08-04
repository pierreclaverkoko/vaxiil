import { HttpClient, HttpResponse } from '@angular/common/http';
import { Injectable, computed, inject, signal } from '@angular/core';
import { firstValueFrom } from 'rxjs';

import { AuthService } from '@/core/auth/auth.service';
import { ApiPaths } from '@/core/constants/api-paths';
import { CountryBrief, parseCountryBrief } from '@/models/organization';
import { environment } from '../../../environments/environment';

const STORAGE_KEY = 'vaxiil.country';
export const RESOLVED_COUNTRY_HEADER = 'X-Resolved-Country';

interface StoredCountry {
  id: string;
  isoCode2: string;
  name?: string;
  flag?: string | null;
}

@Injectable({ providedIn: 'root' })
export class CountryScopeService {
  private readonly http = inject(HttpClient);
  private readonly auth = inject(AuthService);

  private readonly countriesCache = signal<CountryBrief[]>([]);
  private initPromise: Promise<void> | null = null;

  readonly country = signal<CountryBrief | null>(this.readStored());
  readonly countryId = computed(() => this.country()?.id ?? '');
  readonly isoCode2 = computed(() => {
    const code = this.country()?.isoCode2?.trim() ?? '';
    return code ? code.toUpperCase() : '';
  });

  browserTimezone(): string {
    try {
      return Intl.DateTimeFormat().resolvedOptions().timeZone || '';
    } catch {
      return '';
    }
  }

  setCountry(country: CountryBrief): void {
    this.country.set(country);
    this.writeStored(country);
  }

  setCountryById(countryId: string, countries?: CountryBrief[]): void {
    const list = countries?.length ? countries : this.countriesCache();
    const match = list.find((c) => c.id === countryId);
    if (match) {
      this.setCountry(match);
    }
  }

  rememberCountries(countries: CountryBrief[]): void {
    this.countriesCache.set(countries);
  }

  /** Bootstrap once: localStorage → profile default → geo-country → first country. */
  ensureInitialized(countries: CountryBrief[] = []): Promise<void> {
    if (countries.length) {
      this.rememberCountries(countries);
    }
    if (!this.initPromise) {
      this.initPromise = this.bootstrap(countries);
    }
    return this.initPromise;
  }

  /** When storage empty, persist backend-resolved ISO2 if we can map it. */
  hydrateFromResolvedHeader(iso2: string | null | undefined): void {
    if (this.country() || !iso2) {
      return;
    }
    const code = iso2.trim().toUpperCase();
    if (code.length !== 2) {
      return;
    }
    const match = this.countriesCache().find(
      (c) => c.isoCode2.trim().toUpperCase() === code,
    );
    if (match) {
      this.setCountry(match);
    }
  }

  private async bootstrap(countries: CountryBrief[]): Promise<void> {
    const list = countries.length ? countries : this.countriesCache();
    const stored = this.country();
    if (stored) {
      if (list.length) {
        const match = list.find((c) => c.id === stored.id) ??
          list.find((c) => c.isoCode2.toUpperCase() === stored.isoCode2.toUpperCase());
        if (match) {
          this.setCountry(match);
          return;
        }
      }
      return;
    }

    const preferred = this.auth.currentUser()?.defaultCountryId;
    if (preferred && list.length) {
      const match = list.find((c) => c.id === preferred);
      if (match) {
        this.setCountry(match);
        return;
      }
    }

    const detected = await this.fetchGeoCountry();
    if (detected) {
      this.setCountry(detected);
      return;
    }

    if (list[0]) {
      this.setCountry(list[0]);
    }
  }

  private async fetchGeoCountry(): Promise<CountryBrief | null> {
    try {
      const response = await firstValueFrom(
        this.http.get<Record<string, unknown> | null>(
          `${environment.apiBaseUrl}${ApiPaths.organizationsGeoCountry}`,
          {
            observe: 'response',
            headers: {
              'X-Timezone': this.browserTimezone(),
            },
          },
        ),
      );
      if (response.status === 204 || response.body == null) {
        this.captureResolvedHeader(response);
        return null;
      }
      const country = parseCountryBrief(response.body);
      this.captureResolvedHeader(response);
      return country;
    } catch {
      return null;
    }
  }

  private captureResolvedHeader(response: HttpResponse<unknown>): void {
    const iso = response.headers.get(RESOLVED_COUNTRY_HEADER);
    if (iso && !this.country()) {
      this.hydrateFromResolvedHeader(iso);
    }
  }

  private readStored(): CountryBrief | null {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) {
        return null;
      }
      const parsed = JSON.parse(raw) as StoredCountry;
      if (!parsed?.id || !parsed?.isoCode2) {
        return null;
      }
      return {
        id: String(parsed.id),
        isoCode2: String(parsed.isoCode2).toUpperCase(),
        name: parsed.name ?? '',
        flag: parsed.flag ?? null,
        phoneCode: null,
      };
    } catch {
      return null;
    }
  }

  private writeStored(country: CountryBrief): void {
    const payload: StoredCountry = {
      id: country.id,
      isoCode2: country.isoCode2.toUpperCase(),
      name: country.name,
      flag: country.flag,
    };
    localStorage.setItem(STORAGE_KEY, JSON.stringify(payload));
  }
}
