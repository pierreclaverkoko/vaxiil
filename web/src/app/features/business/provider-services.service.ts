import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';

import { ApiPaths } from '@/core/constants/api-paths';
import { mapHttpError } from '@/core/http/api-error';
import { parseJsonList, toPageQuery } from '@/core/http/pagination';
import { LocaleService } from '@/core/i18n/locale.service';
import {
  ServiceDetail,
  ServiceFeatureItem,
  ServiceListItem,
  ServiceSubCategoryBrief,
  parseServiceDetail,
  parseServiceFeatureItem,
  parseServiceListItem,
  parseServiceSubCategoryBrief,
} from '@/models/service-catalog';
import { environment } from '../../../environments/environment';

@Injectable({ providedIn: 'root' })
export class ProviderServicesService {
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

  async listServices(
    organizationId: string,
    opts: { page?: number; pageSize?: number } = {},
  ): Promise<ServiceListItem[]> {
    try {
      let params = new HttpParams();
      const pageQuery = toPageQuery(opts);
      for (const [key, value] of Object.entries(pageQuery)) {
        params = params.set(key, String(value));
      }
      const data = await firstValueFrom(
        this.http.get<unknown>(this.url(ApiPaths.organizationServices(organizationId)), {
          params,
        }),
      );
      return parseJsonList(data, parseServiceListItem);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async getService(organizationId: string, serviceId: string): Promise<ServiceDetail> {
    try {
      const data = await firstValueFrom(
        this.http.get<Record<string, unknown>>(
          this.url(ApiPaths.organizationService(organizationId, serviceId)),
        ),
      );
      return parseServiceDetail(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async createService(
    organizationId: string,
    body: Record<string, unknown>,
  ): Promise<ServiceDetail> {
    try {
      const data = await firstValueFrom(
        this.http.post<Record<string, unknown>>(
          this.url(ApiPaths.organizationServices(organizationId)),
          body,
        ),
      );
      return parseServiceDetail(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async updateService(
    organizationId: string,
    serviceId: string,
    body: Record<string, unknown>,
  ): Promise<ServiceDetail> {
    try {
      const data = await firstValueFrom(
        this.http.patch<Record<string, unknown>>(
          this.url(ApiPaths.organizationService(organizationId, serviceId)),
          body,
        ),
      );
      return parseServiceDetail(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async deleteService(organizationId: string, serviceId: string): Promise<void> {
    try {
      await firstValueFrom(
        this.http.delete<void>(
          this.url(ApiPaths.organizationService(organizationId, serviceId)),
        ),
      );
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async listSubcategories(): Promise<ServiceSubCategoryBrief[]> {
    try {
      const data = await firstValueFrom(
        this.http.get<unknown>(this.url(ApiPaths.serviceSubcategories)),
      );
      return parseJsonList(data, parseServiceSubCategoryBrief);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async listFeatures(): Promise<ServiceFeatureItem[]> {
    try {
      const data = await firstValueFrom(
        this.http.get<unknown>(this.url(ApiPaths.serviceFeatures)),
      );
      return parseJsonList(data, parseServiceFeatureItem);
    } catch (error) {
      throw this.mapError(error);
    }
  }
}
