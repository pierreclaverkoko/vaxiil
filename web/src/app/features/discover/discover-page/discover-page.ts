import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';

import { AuthService } from '@/core/auth/auth.service';
import { ApiError } from '@/core/http/api-error';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { OrganizationsService } from '@/features/business/organizations.service';
import { buildDiscoverServiceSections } from '@/features/discover/discover-sections';
import { DiscoveryService } from '@/features/discover/discovery.service';
import { ServicesCatalogService } from '@/features/services/services-catalog.service';
import { CountryBrief } from '@/models/organization';
import { OrganizationDiscovery } from '@/models/organization-discovery';
import {
  ServiceCategory,
  ServiceListItem,
  formatServicePrice,
  serviceRatingLabel,
} from '@/models/service-catalog';
import { ButtonComponent } from '@/shared/ui/button/button';
import { CountrySelectPillComponent } from '@/shared/ui/country-select-pill/country-select-pill';
import { EmptyStateComponent } from '@/shared/ui/empty-state/empty-state';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';
import { heroiconToMaterialSymbol } from '@/shared/ui/icon/heroicon-to-material';
import { InputComponent } from '@/shared/ui/input/input';

@Component({
  selector: 'app-discover-page',
  standalone: true,
  imports: [
    RouterLink,
    ButtonComponent,
    CountrySelectPillComponent,
    EmptyStateComponent,
    ErrorStateComponent,
    InputComponent,
    TranslatePipe,
  ],
  templateUrl: './discover-page.html',
  styleUrl: './discover-page.scss',
})
export class DiscoverPageComponent implements OnInit {
  private readonly discovery = inject(DiscoveryService);
  private readonly catalog = inject(ServicesCatalogService);
  private readonly orgsApi = inject(OrganizationsService);
  private readonly auth = inject(AuthService);

  protected readonly search = signal('');
  protected readonly selectedCategoryId = signal<string | null>(null);
  protected readonly countryId = signal('');
  protected readonly countries = signal<CountryBrief[]>([]);
  protected readonly venues = signal<OrganizationDiscovery[]>([]);
  protected readonly categories = signal<ServiceCategory[]>([]);
  protected readonly featuredRaw = signal<ServiceListItem[]>([]);
  protected readonly recentRaw = signal<ServiceListItem[]>([]);
  protected readonly totalCount = signal(0);
  protected readonly loading = signal(true);
  protected readonly loadError = signal<string | null>(null);

  protected readonly formatPrice = formatServicePrice;
  protected readonly ratingLabel = serviceRatingLabel;
  protected readonly categoryIcon = heroiconToMaterialSymbol;

  protected readonly sections = computed(() =>
    buildDiscoverServiceSections({
      totalCount: this.totalCount(),
      featured: this.featuredRaw(),
      recent: this.recentRaw(),
    }),
  );

  async ngOnInit(): Promise<void> {
    await this.load();
  }

  protected selectCategory(categoryId: string | null): void {
    this.selectedCategoryId.set(categoryId);
    void this.loadServices();
  }

  protected onSearchChange(value: string): void {
    this.search.set(value);
    void this.loadServices();
  }

  protected onCountryIdChange(countryId: string): void {
    this.countryId.set(countryId);
    void this.loadServices();
  }

  protected onRetry(): void {
    void this.load();
  }

  private async load(): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      const [venues, categories, countries] = await Promise.all([
        this.discovery.listDiscovery(),
        this.catalog.listCategories(),
        this.orgsApi.listCountries(),
      ]);
      this.venues.set(venues);
      this.categories.set(categories.sort((a, b) => a.sortOrder - b.sortOrder));
      this.countries.set(countries);
      if (!this.countryId()) {
        const preferred = this.auth.currentUser()?.defaultCountryId;
        const match = preferred && countries.some((c) => c.id === preferred) ? preferred : '';
        this.countryId.set(match || (countries[0]?.id ?? ''));
      }
      await this.loadServices();
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    } finally {
      this.loading.set(false);
    }
  }

  private async loadServices(): Promise<void> {
    try {
      const filters = {
        search: this.search(),
        categoryId: this.selectedCategoryId() ?? undefined,
        country: this.countryId() || undefined,
      };
      const [featuredPage, recentPage] = await Promise.all([
        this.catalog.listServices({
          ...filters,
          featured: true,
          pageSize: 8,
        }),
        this.catalog.listServices({
          ...filters,
          ordering: '-created_at',
          pageSize: 8,
        }),
      ]);
      this.featuredRaw.set(featuredPage.results);
      this.recentRaw.set(recentPage.results);
      this.totalCount.set(recentPage.count);
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    }
  }
}
