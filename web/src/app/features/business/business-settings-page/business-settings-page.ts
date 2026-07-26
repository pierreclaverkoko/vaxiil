import { Component, OnInit, inject, signal } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';

import { ApiError } from '@/core/http/api-error';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { OrganizationContextService } from '@/features/business/organization-context.service';
import { OrganizationsService } from '@/features/business/organizations.service';
import { Organization, OrganizationAddress } from '@/models/organization';
import { ALL_LOCATION_TYPE_CODES } from '@/models/service-catalog';
import {
  AutocompleteFieldComponent,
  AutocompleteOption,
} from '@/shared/ui/autocomplete-field/autocomplete-field';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ChoiceEnumChipComponent } from '@/shared/ui/choice-enum-chip/choice-enum-chip';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';
import { InputComponent } from '@/shared/ui/input/input';

@Component({
  selector: 'app-business-settings-page',
  standalone: true,
  imports: [
    AutocompleteFieldComponent,
    ButtonComponent,
    ChoiceEnumChipComponent,
    ErrorStateComponent,
    InputComponent,
    TranslatePipe,
  ],
  templateUrl: './business-settings-page.html',
  styleUrl: './business-settings-page.scss',
})
export class BusinessSettingsPageComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly orgsApi = inject(OrganizationsService);
  private readonly orgCtx = inject(OrganizationContextService);
  private readonly locale = inject(LocaleService);

  protected readonly org = signal<Organization | null>(null);
  protected readonly name = signal('');
  protected readonly description = signal('');
  protected readonly phone = signal('');
  protected readonly email = signal('');
  protected readonly website = signal('');
  protected readonly address = signal('');
  protected readonly cityId = signal<string | null>(null);
  protected readonly cityQuery = signal('');
  protected readonly cityOptions = signal<AutocompleteOption[]>([]);
  protected readonly cityLoading = signal(false);
  protected readonly postalCode = signal('');
  protected readonly latitude = signal('');
  protected readonly longitude = signal('');
  protected readonly requireClientName = signal(true);
  protected readonly selectedLocationTypes = signal<Set<string>>(new Set(ALL_LOCATION_TYPE_CODES));
  protected readonly locationTypeOptions = ALL_LOCATION_TYPE_CODES.map((value) => ({ value }));

  protected readonly addresses = signal<OrganizationAddress[]>([]);
  protected readonly addrLabel = signal('');
  protected readonly addrAddress = signal('');
  protected readonly addrPostal = signal('');
  protected readonly addrCityId = signal<string | null>(null);
  protected readonly addrCityQuery = signal('');
  protected readonly addrCityOptions = signal<AutocompleteOption[]>([]);
  protected readonly addrCityLoading = signal(false);
  protected readonly addrEditingId = signal<string | null>(null);
  protected readonly addrBusy = signal(false);

  protected readonly loading = signal(true);
  protected readonly saving = signal(false);
  protected readonly loadError = signal<string | null>(null);
  protected readonly formError = signal<string | null>(null);
  protected readonly formSuccess = signal<string | null>(null);

  private cityTimer: ReturnType<typeof setTimeout> | null = null;
  private addrCityTimer: ReturnType<typeof setTimeout> | null = null;

  async ngOnInit(): Promise<void> {
    const orgId = this.readOrgId();
    if (!orgId) {
      this.loadError.set(this.locale.t('business.errors.missingOrgId'));
      this.loading.set(false);
      return;
    }
    await this.load(orgId);
  }

  protected onRetry(): void {
    const orgId = this.readOrgId();
    if (orgId) {
      void this.load(orgId);
    }
  }

  protected onCityQuery(q: string): void {
    this.cityQuery.set(q);
    this.cityId.set(null);
    this.scheduleCitySearch(q, 'primary');
  }

  protected onCityPick(opt: AutocompleteOption | null): void {
    this.cityId.set(opt?.id ?? null);
    if (opt) {
      this.cityQuery.set(opt.label);
    }
  }

  protected onAddrCityQuery(q: string): void {
    this.addrCityQuery.set(q);
    this.addrCityId.set(null);
    this.scheduleCitySearch(q, 'address');
  }

  protected onAddrCityPick(opt: AutocompleteOption | null): void {
    this.addrCityId.set(opt?.id ?? null);
    if (opt) {
      this.addrCityQuery.set(opt.label);
    }
  }

  protected async onSave(event: Event): Promise<void> {
    event.preventDefault();
    const org = this.org();
    if (!org || this.saving()) {
      return;
    }
    if (!this.cityId()) {
      this.formError.set(this.locale.t('business.settings.cityRequired'));
      return;
    }

    const lat = parseOptionalNumber(this.latitude());
    const lng = parseOptionalNumber(this.longitude());
    if (this.latitude().trim() && lat == null) {
      this.formError.set(this.locale.t('business.settings.invalidCoordinates'));
      return;
    }
    if (this.longitude().trim() && lng == null) {
      this.formError.set(this.locale.t('business.settings.invalidCoordinates'));
      return;
    }

    this.formError.set(null);
    this.formSuccess.set(null);
    this.saving.set(true);
    try {
      const updated = await this.orgsApi.update(org.id, {
        name: this.name().trim(),
        description: this.description().trim() || undefined,
        phone: this.phone().trim() || undefined,
        email: this.email().trim(),
        website: this.website().trim() || undefined,
        requireClientName: this.requireClientName(),
        acceptedLocationTypes: Array.from(this.selectedLocationTypes()),
        primaryAddress: this.address().trim(),
        primaryCityId: this.cityId()!,
        primaryPostalCode: this.postalCode().trim(),
        primaryCountryId: org.countryId ?? undefined,
        primaryLatitude: lat,
        primaryLongitude: lng,
      });
      this.org.set(updated);
      this.hydrate(updated);
      this.orgCtx.upsertLocal(updated);
      this.formSuccess.set(this.locale.t('business.settings.saved'));
    } catch (error) {
      this.formError.set((error as ApiError).message);
    } finally {
      this.saving.set(false);
    }
  }

  protected startEditAddress(addr: OrganizationAddress): void {
    this.addrEditingId.set(addr.id);
    this.addrLabel.set(addr.label ?? '');
    this.addrAddress.set(addr.address);
    this.addrPostal.set(addr.postalCode);
    this.addrCityId.set(addr.cityId);
    this.addrCityQuery.set(addr.city);
    this.addrCityOptions.set(
      addr.cityId ? [{ id: addr.cityId, label: addr.city }] : [],
    );
  }

  protected cancelAddressForm(): void {
    this.addrEditingId.set(null);
    this.addrLabel.set('');
    this.addrAddress.set('');
    this.addrPostal.set('');
    this.addrCityId.set(null);
    this.addrCityQuery.set('');
    this.addrCityOptions.set([]);
  }

  protected async onSaveAddress(event: Event): Promise<void> {
    event.preventDefault();
    const org = this.org();
    if (!org || this.addrBusy()) {
      return;
    }
    if (!this.addrCityId() || !this.addrAddress().trim() || !this.addrPostal().trim()) {
      this.formError.set(this.locale.t('business.settings.addressRequired'));
      return;
    }
    this.formError.set(null);
    this.addrBusy.set(true);
    try {
      const payload = {
        label: this.addrLabel().trim() || undefined,
        address: this.addrAddress().trim(),
        cityId: this.addrCityId()!,
        postalCode: this.addrPostal().trim(),
        countryId: org.countryId ?? undefined,
      };
      const editingId = this.addrEditingId();
      if (editingId) {
        await this.orgsApi.updateAddress(org.id, editingId, payload);
      } else {
        await this.orgsApi.createAddress(org.id, payload);
      }
      this.cancelAddressForm();
      await this.reloadAddresses(org.id);
      this.formSuccess.set(this.locale.t('business.settings.addressSaved'));
    } catch (error) {
      this.formError.set((error as ApiError).message);
    } finally {
      this.addrBusy.set(false);
    }
  }

  protected async onSetPrimary(addr: OrganizationAddress): Promise<void> {
    const org = this.org();
    if (!org || addr.isPrimary || this.addrBusy()) {
      return;
    }
    this.addrBusy.set(true);
    this.formError.set(null);
    try {
      await this.orgsApi.updateAddress(org.id, addr.id, { isPrimary: true });
      const refreshed = await this.orgsApi.getById(org.id);
      this.org.set(refreshed);
      this.hydrate(refreshed);
      this.orgCtx.upsertLocal(refreshed);
      this.formSuccess.set(this.locale.t('business.settings.primaryUpdated'));
    } catch (error) {
      this.formError.set((error as ApiError).message);
    } finally {
      this.addrBusy.set(false);
    }
  }

  protected async onDeleteAddress(addr: OrganizationAddress): Promise<void> {
    const org = this.org();
    if (!org || addr.isPrimary || this.addrBusy()) {
      return;
    }
    if (!confirm(this.locale.t('business.settings.confirmDeleteAddress'))) {
      return;
    }
    this.addrBusy.set(true);
    this.formError.set(null);
    try {
      await this.orgsApi.deleteAddress(org.id, addr.id);
      await this.reloadAddresses(org.id);
      this.formSuccess.set(this.locale.t('business.settings.addressDeleted'));
    } catch (error) {
      this.formError.set((error as ApiError).message);
    } finally {
      this.addrBusy.set(false);
    }
  }

  protected onBack(): void {
    const orgId = this.readOrgId();
    if (orgId) {
      void this.router.navigate(['/business', orgId]);
    }
  }

  private readOrgId(): string | null {
    return this.route.snapshot.paramMap.get('orgId');
  }

  private async load(orgId: string): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      const org = await this.orgsApi.getById(orgId);
      this.org.set(org);
      this.hydrate(org);
      this.orgCtx.upsertLocal(org);
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    } finally {
      this.loading.set(false);
    }
  }

  private async reloadAddresses(orgId: string): Promise<void> {
    const list = await this.orgsApi.listAddresses(orgId);
    this.addresses.set(list);
    const org = this.org();
    if (org) {
      this.org.set({ ...org, addresses: list });
    }
  }

  private scheduleCitySearch(q: string, target: 'primary' | 'address'): void {
    const timer = target === 'primary' ? this.cityTimer : this.addrCityTimer;
    if (timer) {
      clearTimeout(timer);
    }
    const country = this.org()?.countryId;
    if (!country) {
      if (target === 'primary') {
        this.cityOptions.set([]);
      } else {
        this.addrCityOptions.set([]);
      }
      return;
    }
    const handle = setTimeout(() => void this.searchCities(q, target), 300);
    if (target === 'primary') {
      this.cityTimer = handle;
    } else {
      this.addrCityTimer = handle;
    }
  }

  private async searchCities(q: string, target: 'primary' | 'address'): Promise<void> {
    const country = this.org()?.countryId;
    if (!country) {
      return;
    }
    if (target === 'primary') {
      this.cityLoading.set(true);
    } else {
      this.addrCityLoading.set(true);
    }
    try {
      const cities = await this.orgsApi.listCities(country, q);
      const options = cities.map((c) => ({ id: c.id, label: c.name }));
      if (target === 'primary') {
        this.cityOptions.set(options);
      } else {
        this.addrCityOptions.set(options);
      }
    } catch {
      if (target === 'primary') {
        this.cityOptions.set([]);
      } else {
        this.addrCityOptions.set([]);
      }
    } finally {
      if (target === 'primary') {
        this.cityLoading.set(false);
      } else {
        this.addrCityLoading.set(false);
      }
    }
  }

  protected toggleLocationType(code: string, event: Event): void {
    const checked = (event.target as HTMLInputElement).checked;
    this.selectedLocationTypes.update((selected) => {
      const next = new Set(selected);
      if (checked) {
        next.add(code);
      } else {
        next.delete(code);
      }
      return next;
    });
  }

  protected locationTypeLabel(code: string): string {
    switch (code) {
      case 'O':
        return this.locale.t('bookings.locationOffice');
      case 'H':
        return this.locale.t('bookings.locationHome');
      case 'V':
        return this.locale.t('bookings.locationVirtual');
      case 'B':
        return this.locale.t('bookings.locationMobile');
      default:
        return code;
    }
  }

  private hydrate(org: Organization): void {
    this.name.set(org.name);
    this.description.set(org.description ?? '');
    this.phone.set(org.phone ?? '');
    this.email.set(org.email);
    this.website.set(org.website ?? '');
    this.address.set(org.address);
    this.cityId.set(org.cityId);
    this.cityQuery.set(org.city);
    this.cityOptions.set(org.cityId ? [{ id: org.cityId, label: org.city }] : []);
    this.postalCode.set(org.postalCode);
    this.latitude.set(org.latitude != null ? String(org.latitude) : '');
    this.longitude.set(org.longitude != null ? String(org.longitude) : '');
    this.requireClientName.set(org.requireClientName);
    this.addresses.set(org.addresses);
    const types = org.acceptedLocationTypes;
    this.selectedLocationTypes.set(
      new Set(types.length ? types : ALL_LOCATION_TYPE_CODES),
    );
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
