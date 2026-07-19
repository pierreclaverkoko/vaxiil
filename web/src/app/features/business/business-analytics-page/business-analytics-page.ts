import { Component, OnInit, inject, signal } from '@angular/core';
import { ActivatedRoute } from '@angular/router';

import { ApiError } from '@/core/http/api-error';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { OrganizationsService } from '@/features/business/organizations.service';
import { OrganizationAnalytics } from '@/models/organization';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';

@Component({
  selector: 'app-business-analytics-page',
  standalone: true,
  imports: [ButtonComponent, ErrorStateComponent, TranslatePipe],
  templateUrl: './business-analytics-page.html',
  styleUrl: './business-analytics-page.scss',
})
export class BusinessAnalyticsPageComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly orgsApi = inject(OrganizationsService);
  private readonly locale = inject(LocaleService);

  protected readonly analytics = signal<OrganizationAnalytics | null>(null);
  protected readonly loading = signal(true);
  protected readonly loadError = signal<string | null>(null);

  protected readonly revenueLabel = () => {
    const a = this.analytics();
    if (!a) {
      return '—';
    }
    const currency = a.currency ?? '';
    return `${a.revenue} ${currency}`.trim();
  };

  async ngOnInit(): Promise<void> {
    const orgId = this.route.snapshot.paramMap.get('orgId');
    if (!orgId) {
      this.loadError.set(this.locale.t('business.errors.missingOrgId'));
      this.loading.set(false);
      return;
    }
    await this.load(orgId);
  }

  protected onRetry(): void {
    const orgId = this.route.snapshot.paramMap.get('orgId');
    if (orgId) {
      void this.load(orgId);
    }
  }

  private async load(orgId: string): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      this.analytics.set(await this.orgsApi.analytics(orgId));
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    } finally {
      this.loading.set(false);
    }
  }
}
