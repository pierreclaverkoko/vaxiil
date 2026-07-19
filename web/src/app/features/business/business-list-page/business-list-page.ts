import { Component, OnInit, inject, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';

import { ApiError } from '@/core/http/api-error';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { OrganizationContextService } from '@/features/business/organization-context.service';
import { OrganizationsService } from '@/features/business/organizations.service';
import { Organization, OrganizationMineSummary } from '@/models/organization';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ChoiceEnumChipComponent } from '@/shared/ui/choice-enum-chip/choice-enum-chip';
import { EmptyStateComponent } from '@/shared/ui/empty-state/empty-state';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';

@Component({
  selector: 'app-business-list-page',
  standalone: true,
  imports: [
    RouterLink,
    ButtonComponent,
    ChoiceEnumChipComponent,
    EmptyStateComponent,
    ErrorStateComponent,
    TranslatePipe,
  ],
  templateUrl: './business-list-page.html',
  styleUrl: './business-list-page.scss',
})
export class BusinessListPageComponent implements OnInit {
  private readonly orgCtx = inject(OrganizationContextService);
  private readonly orgsApi = inject(OrganizationsService);
  private readonly router = inject(Router);

  protected readonly organizations = signal<Organization[]>([]);
  protected readonly summary = signal<OrganizationMineSummary | null>(null);
  protected readonly loading = signal(true);
  protected readonly loadError = signal<string | null>(null);

  async ngOnInit(): Promise<void> {
    await this.load();
  }

  protected onRetry(): void {
    void this.load();
  }

  protected onSetup(): void {
    void this.router.navigateByUrl('/business/setup');
  }

  private async load(): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      const [orgs, summary] = await Promise.all([
        this.orgCtx.refresh(),
        this.orgsApi.mineSummary(),
      ]);
      this.organizations.set(orgs);
      this.summary.set(summary);
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    } finally {
      this.loading.set(false);
    }
  }
}
