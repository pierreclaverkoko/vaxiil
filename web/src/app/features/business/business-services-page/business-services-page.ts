import { Component, OnInit, inject, signal } from '@angular/core';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';

import { ApiError } from '@/core/http/api-error';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { ProviderServicesService } from '@/features/business/provider-services.service';
import {
  ServiceListItem,
  formatServicePrice,
} from '@/models/service-catalog';
import { ButtonComponent } from '@/shared/ui/button/button';
import { EmptyStateComponent } from '@/shared/ui/empty-state/empty-state';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';

@Component({
  selector: 'app-business-services-page',
  standalone: true,
  imports: [
    RouterLink,
    ButtonComponent,
    EmptyStateComponent,
    ErrorStateComponent,
    TranslatePipe,
  ],
  templateUrl: './business-services-page.html',
  styleUrl: './business-services-page.scss',
})
export class BusinessServicesPageComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly servicesApi = inject(ProviderServicesService);
  private readonly locale = inject(LocaleService);

  protected readonly orgId = signal<string | null>(null);
  protected readonly services = signal<ServiceListItem[]>([]);
  protected readonly loading = signal(true);
  protected readonly loadError = signal<string | null>(null);

  protected readonly formatPrice = (service: ServiceListItem) =>
    service.priceMin === service.priceMax
      ? formatServicePrice(service.priceMin, service.currency)
      : `${formatServicePrice(service.priceMin, service.currency)} – ${formatServicePrice(service.priceMax, service.currency)}`;

  async ngOnInit(): Promise<void> {
    const orgId = this.readOrgId();
    this.orgId.set(orgId);
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

  protected onCreate(): void {
    const orgId = this.readOrgId();
    if (orgId) {
      void this.router.navigate(['/business', orgId, 'services', 'new']);
    }
  }

  private readOrgId(): string | null {
    return this.route.snapshot.paramMap.get('orgId');
  }

  private async load(orgId: string): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      this.services.set(await this.servicesApi.listServices(orgId));
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    } finally {
      this.loading.set(false);
    }
  }
}
