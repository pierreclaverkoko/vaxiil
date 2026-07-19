import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';

import { ApiPaths, DEFAULT_PAGE_SIZE } from '@/core/constants/api-paths';
import { mapHttpError } from '@/core/http/api-error';
import {
  PaginatedResponse,
  parseJsonList,
  parsePaginatedResponse,
  toPageQuery,
} from '@/core/http/pagination';
import { LocaleService } from '@/core/i18n/locale.service';
import {
  ServiceCategory,
  ServiceDetail,
  ServiceListItem,
  parseServiceCategory,
  parseServiceDetail,
  parseServiceListItem,
} from '@/models/service-catalog';
import { environment } from '../../../environments/environment';

export interface ServiceListParams {
  search?: string;
  featured?: boolean;
  categoryId?: string;
  subCategoryId?: string;
  ordering?: string;
  page?: number;
  pageSize?: number;
}

@Injectable({ providedIn: 'root' })
export class ServicesCatalogService {
  private readonly http = inject(HttpClient);
  private readonly locale = inject(LocaleService);

  private url(path: string): string {
    return `${environment.apiBaseUrl}${path}`;
  }

  private mapError(error: unknown) {
    return mapHttpError(error, {
      unexpected: this.locale.t('errors.unexpected'),
      requestFailed: this.locale.t('errors.requestFailed'),
      network: this.locale.t('errors.network'),
    });
  }

  async listCategories(): Promise<ServiceCategory[]> {
    try {
      const data = await firstValueFrom(
        this.http.get<unknown>(this.url(ApiPaths.serviceCategories)),
      );
      return parseJsonList(data, parseServiceCategory);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async listServices(params: ServiceListParams = {}): Promise<PaginatedResponse<ServiceListItem>> {
    try {
      let httpParams = new HttpParams();
      const pageQuery = toPageQuery({
        page: params.page,
        pageSize: params.pageSize ?? DEFAULT_PAGE_SIZE,
      });
      for (const [key, value] of Object.entries(pageQuery)) {
        httpParams = httpParams.set(key, String(value));
      }
      if (params.search?.trim()) {
        httpParams = httpParams.set('search', params.search.trim());
      }
      if (params.featured != null) {
        httpParams = httpParams.set('featured', String(params.featured));
      }
      if (params.categoryId) {
        httpParams = httpParams.set('category', params.categoryId);
      }
      if (params.subCategoryId) {
        httpParams = httpParams.set('sub_category', params.subCategoryId);
      }
      if (params.ordering?.trim()) {
        httpParams = httpParams.set('ordering', params.ordering.trim());
      }

      const data = await firstValueFrom(
        this.http.get<unknown>(this.url(ApiPaths.services), { params: httpParams }),
      );
      return parsePaginatedResponse(data, parseServiceListItem);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async getService(serviceId: string): Promise<ServiceDetail> {
    try {
      const data = await firstValueFrom(
        this.http.get<Record<string, unknown>>(this.url(`${ApiPaths.services}${serviceId}/`)),
      );
      return parseServiceDetail(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }
}
