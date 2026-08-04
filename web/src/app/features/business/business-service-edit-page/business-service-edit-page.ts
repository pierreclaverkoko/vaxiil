import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';

import { ApiError } from '@/core/http/api-error';
import { routeParam } from '@/core/router/route-param';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { OrganizationsService } from '@/features/business/organizations.service';
import { ProviderServicesService } from '@/features/business/provider-services.service';
import { Organization } from '@/models/organization';
import {
  ALL_LOCATION_TYPE_CODES,
  ServiceFeatureItem,
  ServiceSubCategoryBrief,
  formatServicePrice,
} from '@/models/service-catalog';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';
import { InputComponent } from '@/shared/ui/input/input';

@Component({
  selector: 'app-business-service-edit-page',
  standalone: true,
  imports: [ButtonComponent, ErrorStateComponent, InputComponent, TranslatePipe],
  templateUrl: './business-service-edit-page.html',
  styleUrl: './business-service-edit-page.scss',
})
export class BusinessServiceEditPageComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly servicesApi = inject(ProviderServicesService);
  private readonly orgsApi = inject(OrganizationsService);
  private readonly locale = inject(LocaleService);

  private orgSnapshot: Organization | null = null;
  protected readonly hasVenueAddress = signal(false);

  protected readonly subcategories = signal<ServiceSubCategoryBrief[]>([]);
  protected readonly features = signal<ServiceFeatureItem[]>([]);
  protected readonly variants = signal<{ name: string; durationMinutes: string; price: string }[]>(
    [],
  );
  protected readonly selectedFeatureIds = signal<Set<string>>(new Set());
  protected readonly selectedLocationTypes = signal<Set<string>>(new Set());
  protected readonly name = signal('');
  protected readonly description = signal('');
  protected readonly subCategoryId = signal('');
  protected readonly isActive = signal(true);
  protected readonly currencyCode = signal('USD');
  protected readonly existingPrimaryImage = signal<string | null>(null);
  protected readonly pickedImageFile = signal<File | null>(null);
  protected readonly pickedImagePreview = signal<string | null>(null);

  protected readonly isEdit = signal(false);
  protected readonly orgId = signal<string | null>(null);
  protected readonly serviceId = signal<string | null>(null);

  protected readonly loading = signal(true);
  protected readonly saving = signal(false);
  protected readonly loadError = signal<string | null>(null);
  protected readonly formError = signal<string | null>(null);

  protected readonly hasImage = computed(
    () => !!this.pickedImageFile() || !!this.existingPrimaryImage(),
  );

  protected readonly imagePreviewUrl = computed(
    () => this.pickedImagePreview() ?? this.existingPrimaryImage(),
  );

  protected readonly locationTypeOptions = computed(() => {
    this.locale.locale();
    const hasVenue = this.hasVenueAddress();
    return ALL_LOCATION_TYPE_CODES.map((value) => ({
      value,
      label: this.locationTypeLabel(value),
      disabled: value === 'O' && !hasVenue,
    }));
  });

  protected readonly derivedPriceLabel = computed(() => {
    const prices = this.variants()
      .map((variant) => Number(variant.price))
      .filter((price) => Number.isFinite(price) && price >= 0);
    if (!prices.length) {
      return this.locale.t('business.serviceEdit.priceFromVariantsEmpty');
    }
    const min = Math.min(...prices);
    const max = Math.max(...prices);
    const code = this.currencyCode();
    const locale = this.locale.locale();
    if (min === max) {
      return formatServicePrice(min, code, locale);
    }
    return `${formatServicePrice(min, code, locale)} – ${formatServicePrice(max, code, locale)}`;
  });

  async ngOnInit(): Promise<void> {
    const orgId = routeParam(this.route, 'orgId');
    const rawServiceId = routeParam(this.route, 'serviceId');
    const serviceId = rawServiceId && rawServiceId !== 'new' ? rawServiceId : null;

    this.orgId.set(orgId);
    this.serviceId.set(serviceId);
    this.isEdit.set(!!serviceId);

    if (!orgId) {
      this.loadError.set(this.locale.t('business.errors.missingOrgId'));
      this.loading.set(false);
      return;
    }
    await this.bootstrap(orgId, serviceId);
  }

  protected onRetry(): void {
    const orgId = this.orgId();
    const serviceId = this.serviceId();
    if (orgId) {
      void this.bootstrap(orgId, serviceId);
    }
  }

  protected onSubCategoryChange(event: Event): void {
    this.subCategoryId.set((event.target as HTMLSelectElement).value);
  }

  protected onActiveChange(event: Event): void {
    this.isActive.set((event.target as HTMLInputElement).checked);
  }

  protected addVariant(): void {
    this.variants.update((variants) => [
      ...variants,
      { name: '', durationMinutes: '60', price: '' },
    ]);
  }

  protected removeVariant(index: number): void {
    this.variants.update((variants) => variants.filter((_, itemIndex) => itemIndex !== index));
  }

  protected updateVariant(
    index: number,
    field: 'name' | 'durationMinutes' | 'price',
    event: Event,
  ): void {
    const value = (event.target as HTMLInputElement).value;
    this.variants.update((variants) =>
      variants.map((variant, itemIndex) =>
        itemIndex === index ? { ...variant, [field]: value } : variant,
      ),
    );
  }

  protected toggleFeature(featureId: string): void {
    this.selectedFeatureIds.update((selected) => {
      const next = new Set(selected);
      if (next.has(featureId)) {
        next.delete(featureId);
      } else {
        next.add(featureId);
      }
      return next;
    });
  }

  protected truncatedDescription(text: string | null): string {
    const value = (text ?? '').trim();
    if (value.length <= 90) {
      return value;
    }
    return `${value.slice(0, 90)}…`;
  }

  protected featureIcon(icon: string | null): string {
    const name = (icon ?? '').trim();
    return name || 'star';
  }

  protected onImageSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0] ?? null;
    const previous = this.pickedImagePreview();
    if (previous) {
      URL.revokeObjectURL(previous);
    }
    if (!file) {
      this.pickedImageFile.set(null);
      this.pickedImagePreview.set(null);
      return;
    }
    this.pickedImageFile.set(file);
    this.pickedImagePreview.set(URL.createObjectURL(file));
  }

  protected toggleLocationType(code: string, event: Event): void {
    const checked = (event.target as HTMLInputElement).checked;
    if (code === 'O' && checked && !this.hasVenueAddress()) {
      (event.target as HTMLInputElement).checked = false;
      return;
    }
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

  protected async onSave(event: Event): Promise<void> {
    event.preventDefault();
    const orgId = this.orgId();
    if (!orgId || this.saving()) {
      return;
    }
    if (!this.subCategoryId()) {
      this.formError.set(this.locale.t('business.serviceEdit.subCategoryRequired'));
      return;
    }

    const variantsPayload = this.variants()
      .filter((variant) => variant.durationMinutes.trim() && variant.price.trim())
      .map((variant) => ({
        name: variant.name.trim(),
        duration_minutes: Number(variant.durationMinutes),
        duration_type: 'F',
        price: variant.price.trim(),
        is_active: true,
        is_popular: false,
      }));

    if (!variantsPayload.length) {
      this.formError.set(this.locale.t('business.serviceEdit.variantRequired'));
      return;
    }
    if (!this.hasImage()) {
      this.formError.set(this.locale.t('business.serviceEdit.imageRequired'));
      return;
    }

    this.formError.set(null);
    this.saving.set(true);
    const org = this.orgSnapshot;
    const body: Record<string, unknown> = {
      name: this.name().trim(),
      description: this.description().trim(),
      sub_category: this.subCategoryId(),
      is_active: this.isActive(),
      availability_type: 'P',
      show_location_on_listing: true,
      accepted_location_types: Array.from(this.selectedLocationTypes()),
      address: org?.address ?? '',
      city_id: org?.cityId ?? null,
      postal_code: org?.postalCode ?? '',
      country_text: org?.country ?? '',
      variants: variantsPayload,
      feature_mappings: Array.from(this.selectedFeatureIds()).map((feature) => ({
        feature,
        is_required: false,
      })),
    };
    if (org?.countryId) {
      body['country'] = org.countryId;
    }
    if (org?.defaultCurrencyId) {
      body['accepted_currency'] = org.defaultCurrencyId;
    }

    try {
      let serviceId = this.serviceId();
      if (serviceId) {
        await this.servicesApi.updateService(orgId, serviceId, body);
      } else {
        const created = await this.servicesApi.createService(orgId, body);
        serviceId = created.id;
      }
      const imageFile = this.pickedImageFile();
      if (imageFile && serviceId) {
        await this.servicesApi.uploadPrimaryImage(orgId, serviceId, imageFile);
      }
      await this.router.navigate(['/business', orgId, 'services']);
    } catch (error) {
      this.formError.set((error as ApiError).message);
    } finally {
      this.saving.set(false);
    }
  }

  protected async onDelete(): Promise<void> {
    const orgId = this.orgId();
    const serviceId = this.serviceId();
    if (!orgId || !serviceId || this.saving()) {
      return;
    }
    if (!confirm(this.locale.t('business.serviceEdit.confirmDelete'))) {
      return;
    }
    this.saving.set(true);
    try {
      await this.servicesApi.deleteService(orgId, serviceId);
      await this.router.navigate(['/business', orgId, 'services']);
    } catch (error) {
      this.formError.set((error as ApiError).message);
    } finally {
      this.saving.set(false);
    }
  }

  protected onBack(): void {
    const orgId = this.orgId();
    if (orgId) {
      void this.router.navigate(['/business', orgId, 'services']);
    }
  }

  private locationTypeLabel(code: string): string {
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

  private async bootstrap(orgId: string, serviceId: string | null): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      const [subs, org] = await Promise.all([
        this.servicesApi.listSubcategories(),
        this.orgsApi.getById(orgId),
      ]);
      try {
        this.features.set(await this.servicesApi.listFeatures());
      } catch {
        this.features.set([]);
      }
      this.orgSnapshot = org;
      this.hasVenueAddress.set(org.hasVenueAddress);
      this.subcategories.set(subs);
      if (serviceId) {
        const detail = await this.servicesApi.getService(orgId, serviceId);
        this.name.set(detail.name);
        this.description.set(detail.description);
        this.currencyCode.set(detail.currency || 'USD');
        this.subCategoryId.set(detail.subCategory.id);
        this.isActive.set(detail.isActive);
        this.variants.set(
          detail.variants.map((variant) => ({
            name: variant.name,
            durationMinutes: String(variant.durationMinutes),
            price: String(variant.price),
          })),
        );
        this.selectedFeatureIds.set(
          new Set(detail.featureMappings.map((mapping) => mapping.feature.id)),
        );
        const locs = new Set(detail.acceptedLocationTypes);
        if (!org.hasVenueAddress) {
          locs.delete('O');
        }
        this.selectedLocationTypes.set(locs);
        this.existingPrimaryImage.set(detail.primaryImage);
      } else if (subs.length) {
        this.subCategoryId.set(subs[0].id);
      }
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    } finally {
      this.loading.set(false);
    }
  }
}
