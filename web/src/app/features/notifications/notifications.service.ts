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

  async list(params: { page?: number; pageSize?: number } = {}): Promise<
    PaginatedResponse<AppNotification>
  > {
    try {
      let httpParams = new HttpParams();
      const pageQuery = toPageQuery(params);
      for (const [key, value] of Object.entries(pageQuery)) {
        httpParams = httpParams.set(key, String(value));
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

  async markAllRead(): Promise<number> {
    try {
      const data = await firstValueFrom(
        this.http.post<{ updated?: number }>(
          this.url(ApiPaths.notificationsMarkAllRead),
          {},
        ),
      );
      return typeof data.updated === 'number' ? data.updated : 0;
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async unreadCount(): Promise<number> {
    try {
      const data = await firstValueFrom(
        this.http.get<{ unread_count?: number }>(
          this.url(ApiPaths.notificationsUnreadCount),
        ),
      );
      return typeof data.unread_count === 'number' ? data.unread_count : 0;
    } catch (error) {
      throw this.mapError(error);
    }
  }
}
