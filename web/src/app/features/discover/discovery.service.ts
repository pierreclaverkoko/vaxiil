import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';

import { ApiPaths } from '@/core/constants/api-paths';
import { mapHttpError } from '@/core/http/api-error';
import {
  PageParams,
  PaginatedResponse,
  parsePaginatedResponse,
  toPageQuery,
} from '@/core/http/pagination';
import { LocaleService } from '@/core/i18n/locale.service';
import {
  OrganizationDiscovery,
  parseOrganizationDiscovery,
} from '@/models/organization-discovery';
import { environment } from '../../../environments/environment';

export interface DiscoveryListParams extends PageParams {
  country?: string;
}

@Injectable({ providedIn: 'root' })
export class DiscoveryService {
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

  async listDiscovery(
    params: DiscoveryListParams = {},
  ): Promise<PaginatedResponse<OrganizationDiscovery>> {
    try {
      let httpParams = new HttpParams();
      const pageQuery = toPageQuery(params);
      for (const [key, value] of Object.entries(pageQuery)) {
        httpParams = httpParams.set(key, String(value));
      }
      if (params.country) {
        httpParams = httpParams.set('country', params.country);
      }
      const data = await firstValueFrom(
        this.http.get<unknown>(this.url(ApiPaths.organizationsDiscovery), {
          params: httpParams,
        }),
      );
      return parsePaginatedResponse(data, parseOrganizationDiscovery);
    } catch (error) {
      throw this.mapError(error);
    }
  }
}
