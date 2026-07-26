import { Component, OnInit, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { ApiError } from '@/core/http/api-error';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { OrganizationContextService } from '@/features/business/organization-context.service';
import { OrganizationsService } from '@/features/business/organizations.service';
import {
  CountryBrief,
  OrganizationTypeOption,
} from '@/models/organization';
import {
  AutocompleteFieldComponent,
  AutocompleteOption,
} from '@/shared/ui/autocomplete-field/autocomplete-field';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';
import { InputComponent } from '@/shared/ui/input/input';

@Component({
  selector: 'app-business-setup-page',
  standalone: true,
  imports: [
    AutocompleteFieldComponent,
    ButtonComponent,
    ErrorStateComponent,
    InputComponent,
    TranslatePipe,
  ],
  templateUrl: './business-setup-page.html',
  styleUrl: './business-setup-page.scss',
})
export class BusinessSetupPageComponent implements OnInit {
  private readonly orgsApi = inject(OrganizationsService);
  private readonly orgCtx = inject(OrganizationContextService);
  private readonly router = inject(Router);
  private readonly locale = inject(LocaleService);

  protected readonly types = signal<OrganizationTypeOption[]>([]);
  protected readonly countries = signal<CountryBrief[]>([]);
  protected readonly typeId = signal('');
  protected readonly name = signal('');
  protected readonly email = signal('');
  protected readonly phone = signal('');
  protected readonly description = signal('');
  protected readonly address = signal('');
  protected readonly cityId = signal<string | null>(null);
  protected readonly cityQuery = signal('');
  protected readonly cityOptions = signal<AutocompleteOption[]>([]);
  protected readonly cityLoading = signal(false);
  protected readonly postalCode = signal('');
  protected readonly countryId = signal('');
  protected readonly latitude = signal('');
  protected readonly longitude = signal('');
  protected readonly logoFile = signal<File | null>(null);
  protected readonly logoPreview = signal<string | null>(null);

  protected readonly loading = signal(true);
  protected readonly submitting = signal(false);
  protected readonly loadError = signal<string | null>(null);
  protected readonly formError = signal<string | null>(null);

  private cityTimer: ReturnType<typeof setTimeout> | null = null;

  async ngOnInit(): Promise<void> {
    await this.loadReferenceData();
  }

  protected onRetry(): void {
    void this.loadReferenceData();
  }

  protected onTypeChange(event: Event): void {
    this.typeId.set((event.target as HTMLSelectElement).value);
  }

  protected onCountryChange(event: Event): void {
    this.countryId.set((event.target as HTMLSelectElement).value);
    this.clearCity();
  }

  protected onCityQuery(q: string): void {
    this.cityQuery.set(q);
    this.cityId.set(null);
    if (this.cityTimer) {
      clearTimeout(this.cityTimer);
    }
    const country = this.countryId();
    if (!country) {
      this.cityOptions.set([]);
      return;
    }
    this.cityTimer = setTimeout(() => void this.searchCities(q), 300);
  }

  protected onCityPick(opt: AutocompleteOption | null): void {
    this.cityId.set(opt?.id ?? null);
    if (opt) {
      this.cityQuery.set(opt.label);
    }
  }

  protected onLogoSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) {
      return;
    }
    this.logoFile.set(file);
    const reader = new FileReader();
    reader.onload = () => {
      this.logoPreview.set(typeof reader.result === 'string' ? reader.result : null);
    };
    reader.readAsDataURL(file);
  }

  protected async onSubmit(event: Event): Promise<void> {
    event.preventDefault();
    if (this.submitting()) {
      return;
    }
    this.formError.set(null);

    const logo = this.logoFile();
    if (!logo) {
      this.formError.set(this.locale.t('business.setup.logoRequired'));
      return;
    }
    if (!this.typeId() || !this.countryId() || !this.cityId()) {
      this.formError.set(this.locale.t('business.setup.requiredFields'));
      return;
    }

    const lat = parseOptionalNumber(this.latitude());
    const lng = parseOptionalNumber(this.longitude());
    if (this.latitude().trim() && lat == null) {
      this.formError.set(this.locale.t('business.setup.invalidCoordinates'));
      return;
    }
    if (this.longitude().trim() && lng == null) {
      this.formError.set(this.locale.t('business.setup.invalidCoordinates'));
      return;
    }

    this.submitting.set(true);
    try {
      const org = await this.orgsApi.create({
        typeId: this.typeId(),
        name: this.name().trim(),
        email: this.email().trim(),
        address: this.address().trim(),
        cityId: this.cityId()!,
        postalCode: this.postalCode().trim(),
        countryId: this.countryId(),
        logo,
        phone: this.phone().trim() || undefined,
        description: this.description().trim() || undefined,
        latitude: lat ?? undefined,
        longitude: lng ?? undefined,
      });
      this.orgCtx.upsertLocal(org);
      await this.router.navigate(['/business', org.id]);
    } catch (error) {
      this.formError.set((error as ApiError).message);
    } finally {
      this.submitting.set(false);
    }
  }

  private clearCity(): void {
    this.cityId.set(null);
    this.cityQuery.set('');
    this.cityOptions.set([]);
  }

  private async searchCities(q: string): Promise<void> {
    const country = this.countryId();
    if (!country) {
      return;
    }
    this.cityLoading.set(true);
    try {
      const cities = await this.orgsApi.listCities(country, q);
      this.cityOptions.set(cities.map((c) => ({ id: c.id, label: c.name })));
    } catch {
      this.cityOptions.set([]);
    } finally {
      this.cityLoading.set(false);
    }
  }

  private async loadReferenceData(): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      const [types, countries] = await Promise.all([
        this.orgsApi.listTypes(),
        this.orgsApi.listCountries(),
      ]);
      this.types.set(types);
      this.countries.set(countries);
      if (!this.typeId() && types.length) {
        this.typeId.set(types[0].id);
      }
      if (!this.countryId() && countries.length) {
        const us = countries.find((c) => c.isoCode2 === 'US');
        this.countryId.set(us?.id ?? countries[0].id);
      }
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    } finally {
      this.loading.set(false);
    }
  }
}

function parseOptionalNumber(raw: string): number | null {
  const trimmed = raw.trim();
  if (!trimmed) {
    return null;
  }
  const n = Number(trimmed);
  return Number.isFinite(n) ? n : null;
}
