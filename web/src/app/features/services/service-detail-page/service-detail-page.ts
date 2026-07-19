import { Component, OnInit, inject, signal } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';

import { AuthService } from '@/core/auth/auth.service';
import { ApiError } from '@/core/http/api-error';
import { routeParam } from '@/core/router/route-param';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { ServicesCatalogService } from '@/features/services/services-catalog.service';
import {
  ServiceDetail,
  ServiceVariantDetail,
  formatServicePrice,
  serviceRatingLabel,
} from '@/models/service-catalog';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ChoiceEnumChipComponent } from '@/shared/ui/choice-enum-chip/choice-enum-chip';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';

@Component({
  selector: 'app-service-detail-page',
  standalone: true,
  imports: [
    ButtonComponent,
    ChoiceEnumChipComponent,
    ErrorStateComponent,
    TranslatePipe,
  ],
  templateUrl: './service-detail-page.html',
  styleUrl: './service-detail-page.scss',
})
export class ServiceDetailPageComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly catalog = inject(ServicesCatalogService);
  private readonly auth = inject(AuthService);

  protected readonly service = signal<ServiceDetail | null>(null);
  protected readonly loading = signal(true);
  protected readonly loadError = signal<string | null>(null);

  protected readonly formatPrice = formatServicePrice;
  protected readonly ratingLabel = serviceRatingLabel;

  async ngOnInit(): Promise<void> {
    const id = routeParam(this.route, 'id');
    if (!id) {
      this.loadError.set('Missing service id');
      this.loading.set(false);
      return;
    }
    await this.load(id);
  }

  protected activeVariants(variants: ServiceVariantDetail[]): ServiceVariantDetail[] {
    return variants.filter((v) => v.isActive);
  }

  protected onRetry(): void {
    const id = routeParam(this.route, 'id');
    if (id) {
      void this.load(id);
    }
  }

  protected onBook(serviceId: string): void {
    const bookUrl = `/services/${serviceId}/book`;
    if (!this.auth.isAuthenticated()) {
      void this.router.navigate(['/login'], {
        queryParams: { returnUrl: bookUrl },
      });
      return;
    }
    void this.router.navigateByUrl(bookUrl);
  }

  private async load(id: string): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      this.service.set(await this.catalog.getService(id));
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    } finally {
      this.loading.set(false);
    }
  }
}
