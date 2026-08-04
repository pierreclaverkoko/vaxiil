import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';

import { CountryScopeService } from '@/core/country/country-scope.service';
import { ApiError } from '@/core/http/api-error';
import { hasMorePages } from '@/core/http/pagination';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { OrganizationsService } from '@/features/business/organizations.service';
import { DiscoveryService } from '@/features/discover/discovery.service';
import { CountryBrief } from '@/models/organization';
import { OrganizationDiscovery } from '@/models/organization-discovery';
import { ButtonComponent } from '@/shared/ui/button/button';
import { CountrySelectPillComponent } from '@/shared/ui/country-select-pill/country-select-pill';
import { EmptyStateComponent } from '@/shared/ui/empty-state/empty-state';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';

@Component({
  selector: 'app-venues-list-page',
  standalone: true,
  imports: [
    RouterLink,
    ButtonComponent,
    CountrySelectPillComponent,
    EmptyStateComponent,
    ErrorStateComponent,
    TranslatePipe,
  ],
  templateUrl: './venues-list-page.html',
  styleUrl: './venues-list-page.scss',
})
export class VenuesListPageComponent implements OnInit {
  private readonly discovery = inject(DiscoveryService);
  private readonly orgsApi = inject(OrganizationsService);
  private readonly countryScope = inject(CountryScopeService);

  protected readonly countries = signal<CountryBrief[]>([]);
  protected readonly venues = signal<OrganizationDiscovery[]>([]);
  protected readonly page = signal(1);
  protected readonly hasMore = signal(false);
  protected readonly loading = signal(true);
  protected readonly loadingMore = signal(false);
  protected readonly loadError = signal<string | null>(null);

  protected readonly countryId = computed(() => this.countryScope.countryId());

  async ngOnInit(): Promise<void> {
    await this.load();
  }

  protected onCountryIdChange(countryId: string): void {
    this.countryScope.setCountryById(countryId, this.countries());
    void this.reload();
  }

  protected onRetry(): void {
    void this.load();
  }

  protected async loadMore(): Promise<void> {
    if (this.loadingMore() || !this.hasMore()) {
      return;
    }
    this.loadingMore.set(true);
    try {
      const nextPage = this.page() + 1;
      const result = await this.discovery.listDiscovery({
        country: this.countryId() || undefined,
        page: nextPage,
        pageSize: 20,
      });
      this.venues.update((rows) => [...rows, ...result.results]);
      this.page.set(nextPage);
      this.hasMore.set(hasMorePages(result));
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    } finally {
      this.loadingMore.set(false);
    }
  }

  private async load(): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      const countries = await this.orgsApi.listCountries();
      this.countries.set(countries);
      await this.countryScope.ensureInitialized(countries);
      await this.reload();
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    } finally {
      this.loading.set(false);
    }
  }

  private async reload(): Promise<void> {
    this.page.set(1);
    const result = await this.discovery.listDiscovery({
      country: this.countryId() || undefined,
      page: 1,
      pageSize: 20,
    });
    this.venues.set(result.results);
    this.hasMore.set(hasMorePages(result));
  }
}
