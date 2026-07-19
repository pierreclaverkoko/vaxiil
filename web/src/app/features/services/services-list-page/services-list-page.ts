import { Component, OnInit, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';

import { ApiError } from '@/core/http/api-error';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { ServicesCatalogService } from '@/features/services/services-catalog.service';
import {
  ServiceCategory,
  ServiceListItem,
  formatServicePrice,
  serviceRatingLabel,
} from '@/models/service-catalog';
import { ButtonComponent } from '@/shared/ui/button/button';
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

  protected readonly search = signal('');
  protected readonly selectedCategoryId = signal<string | null>(null);
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

  protected onRetry(): void {
    void this.load();
  }

  private async load(): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      this.categories.set(
        (await this.catalog.listCategories()).sort((a, b) => a.sortOrder - b.sortOrder),
      );
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
      });
      this.services.set(page.results);
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    }
  }
}
