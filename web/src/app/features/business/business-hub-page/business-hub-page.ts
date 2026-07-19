import { Component, OnInit, inject, signal } from '@angular/core';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';

import { ApiError } from '@/core/http/api-error';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { OrganizationContextService } from '@/features/business/organization-context.service';
import { OrganizationsService } from '@/features/business/organizations.service';
import { Organization, isOrgVerified } from '@/models/organization';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ChoiceEnumChipComponent } from '@/shared/ui/choice-enum-chip/choice-enum-chip';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';
import { InputComponent } from '@/shared/ui/input/input';

type HubPhase = 'verified' | 'kybPending' | 'kybNotSent';

function hubPhase(org: Organization): HubPhase {
  if (isOrgVerified(org)) {
    return 'verified';
  }
  const code = org.verificationStatus?.value ?? '';
  if (code === 'P' && org.kybSubmittedAt) {
    return 'kybPending';
  }
  return 'kybNotSent';
}

interface HubLink {
  path: string;
  labelKey: string;
  icon: string;
}

@Component({
  selector: 'app-business-hub-page',
  standalone: true,
  imports: [
    RouterLink,
    ButtonComponent,
    ChoiceEnumChipComponent,
    ErrorStateComponent,
    InputComponent,
    TranslatePipe,
  ],
  templateUrl: './business-hub-page.html',
  styleUrl: './business-hub-page.scss',
})
export class BusinessHubPageComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly orgsApi = inject(OrganizationsService);
  private readonly orgCtx = inject(OrganizationContextService);
  private readonly locale = inject(LocaleService);

  protected readonly org = signal<Organization | null>(null);
  protected readonly phase = signal<HubPhase>('kybNotSent');
  protected readonly loading = signal(true);
  protected readonly loadError = signal<string | null>(null);
  protected readonly formError = signal<string | null>(null);
  protected readonly formSuccess = signal<string | null>(null);
  protected readonly submittingKyb = signal(false);
  protected readonly moreOpen = signal(false);

  protected readonly licenseNumber = signal('');
  protected readonly taxId = signal('');
  protected readonly licenseFile = signal<File | null>(null);
  protected readonly idDocFile = signal<File | null>(null);

  protected readonly hubLinks = signal<HubLink[]>([]);

  async ngOnInit(): Promise<void> {
    const orgId = this.readOrgId();
    if (!orgId) {
      this.loadError.set(this.locale.t('business.errors.missingOrgId'));
      this.loading.set(false);
      return;
    }
    this.orgCtx.setCurrentOrgId(orgId);
    await this.load(orgId);
  }

  protected onRetry(): void {
    const orgId = this.readOrgId();
    if (orgId) {
      void this.load(orgId);
    }
  }

  protected openMore(): void {
    this.moreOpen.set(true);
  }

  protected closeMore(): void {
    this.moreOpen.set(false);
  }

  protected onLicenseSelected(event: Event): void {
    const file = (event.target as HTMLInputElement).files?.[0];
    if (file) {
      this.licenseFile.set(file);
    }
  }

  protected onIdDocSelected(event: Event): void {
    const file = (event.target as HTMLInputElement).files?.[0];
    if (file) {
      this.idDocFile.set(file);
    }
  }

  protected async onSubmitKyb(event: Event): Promise<void> {
    event.preventDefault();
    const org = this.org();
    const license = this.licenseFile();
    const idDoc = this.idDocFile();
    if (!org || this.submittingKyb()) {
      return;
    }
    if (!license || !idDoc) {
      this.formError.set(this.locale.t('business.hub.kybDocsRequired'));
      return;
    }
    this.formError.set(null);
    this.formSuccess.set(null);
    this.submittingKyb.set(true);
    try {
      const updated = await this.orgsApi.submitVerification(org.id, {
        businessLicense: license,
        idDocument: idDoc,
        businessLicenseNumber: this.licenseNumber().trim() || undefined,
        taxId: this.taxId().trim() || undefined,
      });
      this.org.set(updated);
      this.phase.set(hubPhase(updated));
      this.orgCtx.upsertLocal(updated);
      this.formSuccess.set(this.locale.t('business.hub.kybSubmitted'));
    } catch (error) {
      this.formError.set((error as ApiError).message);
    } finally {
      this.submittingKyb.set(false);
    }
  }

  protected navigateFromMore(path: string): void {
    this.closeMore();
    void this.router.navigateByUrl(path);
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
      this.phase.set(hubPhase(org));
      this.licenseNumber.set(org.businessLicenseNumber ?? '');
      this.taxId.set(org.taxId ?? '');
      this.orgCtx.upsertLocal(org);
      this.hubLinks.set(this.buildLinks(orgId));
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    } finally {
      this.loading.set(false);
    }
  }

  private buildLinks(orgId: string): HubLink[] {
    const base = `/business/${orgId}`;
    return [
      { path: `${base}/services`, labelKey: 'business.hub.linkServices', icon: 'spa' },
      { path: `${base}/bookings`, labelKey: 'business.hub.linkBookings', icon: 'event_available' },
      { path: `${base}/team`, labelKey: 'business.hub.linkTeam', icon: 'group' },
      { path: `${base}/analytics`, labelKey: 'business.hub.linkAnalytics', icon: 'auto_graph' },
      { path: `${base}/settings`, labelKey: 'business.hub.linkSettings', icon: 'settings' },
    ];
  }
}
