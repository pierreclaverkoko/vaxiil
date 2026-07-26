import { Component, OnInit, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';

import { AuthService } from '@/core/auth/auth.service';
import { ApiError } from '@/core/http/api-error';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { OrganizationsService } from '@/features/business/organizations.service';
import { ServicesCatalogService } from '@/features/services/services-catalog.service';
import { CountryBrief } from '@/models/organization';
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
  selector: 'app-services-list-page',
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
  templateUrl: './services-list-page.html',
  styleUrl: './services-list-page.scss',
})
export class ServicesListPageComponent implements OnInit {
  private readonly catalog = inject(ServicesCatalogService);
  private readonly orgsApi = inject(OrganizationsService);
  private readonly auth = inject(AuthService);

  protected readonly search = signal('');
  protected readonly selectedCategoryId = signal<string | null>(null);
  protected readonly countryId = signal('');
  protected readonly countries = signal<CountryBrief[]>([]);
  protected readonly categories = signal<ServiceCategory[]>([]);
  protected readonly services = signal<ServiceListItem[]>([]);
  protected readonly loading = signal(true);
  protected readonly loadError = signal<string | null>(null);

  protected readonly formatPrice = formatServicePrice;
  protected readonly ratingLabel = serviceRatingLabel;
  protected readonly categoryIcon = heroiconToMaterialSymbol;

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
      const [categories, countries] = await Promise.all([
        this.catalog.listCategories(),
        this.orgsApi.listCountries(),
      ]);
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
      const page = await this.catalog.listServices({
        search: this.search(),
        categoryId: this.selectedCategoryId() ?? undefined,
        country: this.countryId() || undefined,
      });
      this.services.set(page.results);
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    }
  }
}
