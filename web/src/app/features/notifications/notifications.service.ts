import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';

import { ApiPaths } from '@/core/constants/api-paths';
import { mapHttpError } from '@/core/http/api-error';
import { PaginatedResponse, parsePaginatedResponse, toPageQuery } from '@/core/http/pagination';
import { LocaleService } from '@/core/i18n/locale.service';
import { AppNotification, parseAppNotification } from '@/models/notification';
import { environment } from '../../../environments/environment';

@Injectable({ providedIn: 'root' })
export class NotificationsService {
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

  async list(
    params: {
      page?: number;
      pageSize?: number;
      scope?: 'personal' | 'staff';
      organizationId?: string;
    } = {},
  ): Promise<PaginatedResponse<AppNotification>> {
    try {
      let httpParams = new HttpParams();
      const pageQuery = toPageQuery(params);
      for (const [key, value] of Object.entries(pageQuery)) {
        httpParams = httpParams.set(key, String(value));
      }
      if (params.organizationId) {
        httpParams = httpParams.set('organization_id', params.organizationId);
      } else if (params.scope) {
        httpParams = httpParams.set('scope', params.scope);
      } else {
        httpParams = httpParams.set('scope', 'personal');
      }
      const data = await firstValueFrom(
        this.http.get<unknown>(this.url(ApiPaths.notifications), { params: httpParams }),
      );
      return parsePaginatedResponse(data, parseAppNotification);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async markRead(id: string): Promise<AppNotification> {
    try {
      const data = await firstValueFrom(
        this.http.post<Record<string, unknown>>(
          this.url(ApiPaths.notificationMarkRead(id)),
          {},
        ),
      );
      return parseAppNotification(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async markAllRead(params: {
    scope?: 'personal' | 'staff';
    organizationId?: string;
  } = {}): Promise<number> {
    try {
      let httpParams = new HttpParams();
      if (params.organizationId) {
        httpParams = httpParams.set('organization_id', params.organizationId);
      } else if (params.scope) {
        httpParams = httpParams.set('scope', params.scope);
      } else {
        httpParams = httpParams.set('scope', 'personal');
      }
      const data = await firstValueFrom(
        this.http.post<{ updated?: number }>(
          this.url(ApiPaths.notificationsMarkAllRead),
          {},
          { params: httpParams },
        ),
      );
      return typeof data.updated === 'number' ? data.updated : 0;
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async unreadCount(params: {
    scope?: 'personal' | 'staff';
    organizationId?: string;
  } = {}): Promise<number> {
    try {
      let httpParams = new HttpParams();
      if (params.organizationId) {
        httpParams = httpParams.set('organization_id', params.organizationId);
      } else if (params.scope) {
        httpParams = httpParams.set('scope', params.scope);
      } else {
        httpParams = httpParams.set('scope', 'personal');
      }
      const data = await firstValueFrom(
        this.http.get<{ unread_count?: number }>(
          this.url(ApiPaths.notificationsUnreadCount),
          { params: httpParams },
        ),
      );
      return typeof data.unread_count === 'number' ? data.unread_count : 0;
    } catch (error) {
      throw this.mapError(error);
    }
  }
}
