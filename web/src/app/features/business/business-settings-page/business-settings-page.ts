import { Component, OnInit, inject, signal } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';

import { ApiError } from '@/core/http/api-error';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { OrganizationContextService } from '@/features/business/organization-context.service';
import { OrganizationsService } from '@/features/business/organizations.service';
import { Organization } from '@/models/organization';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ChoiceEnumChipComponent } from '@/shared/ui/choice-enum-chip/choice-enum-chip';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';
import { InputComponent } from '@/shared/ui/input/input';

@Component({
  selector: 'app-business-settings-page',
  standalone: true,
  imports: [
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
  protected readonly city = signal('');
  protected readonly postalCode = signal('');
  protected readonly requireClientName = signal(true);

  protected readonly loading = signal(true);
  protected readonly saving = signal(false);
  protected readonly loadError = signal<string | null>(null);
  protected readonly formError = signal<string | null>(null);
  protected readonly formSuccess = signal<string | null>(null);

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

  protected async onSave(event: Event): Promise<void> {
    event.preventDefault();
    const org = this.org();
    if (!org || this.saving()) {
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
        primaryAddress: this.address().trim(),
        primaryCity: this.city().trim(),
        primaryPostalCode: this.postalCode().trim(),
        primaryCountryId: org.countryId ?? undefined,
        primaryLatitude: org.latitude ?? undefined,
        primaryLongitude: org.longitude ?? undefined,
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

  private hydrate(org: Organization): void {
    this.name.set(org.name);
    this.description.set(org.description ?? '');
    this.phone.set(org.phone ?? '');
    this.email.set(org.email);
    this.website.set(org.website ?? '');
    this.address.set(org.address);
    this.city.set(org.city);
    this.postalCode.set(org.postalCode);
    this.requireClientName.set(org.requireClientName);
  }
}
