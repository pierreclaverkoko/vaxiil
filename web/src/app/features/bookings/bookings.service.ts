import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';

import { ApiPaths } from '@/core/constants/api-paths';
import { mapHttpError } from '@/core/http/api-error';
import { PaginatedResponse, parsePaginatedResponse, toPageQuery } from '@/core/http/pagination';
import { LocaleService } from '@/core/i18n/locale.service';
import { withOptionalClientLocation } from '@/core/utils/client-location';
import {
  BookingCreatePayload,
  BookingDetail,
  BookingListItem,
  BookingTimeSlotWrite,
  parseBookingDetail,
  parseBookingListItem,
} from '@/models/booking';
import { environment } from '../../../environments/environment';

export interface BookingListParams {
  page?: number;
  pageSize?: number;
  organizationId?: string;
}

@Injectable({ providedIn: 'root' })
export class BookingsService {
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

  async listMine(params: BookingListParams = {}): Promise<PaginatedResponse<BookingListItem>> {
    try {
      let httpParams = new HttpParams();
      const pageQuery = toPageQuery(params);
      for (const [key, value] of Object.entries(pageQuery)) {
        httpParams = httpParams.set(key, String(value));
      }
      if (params.organizationId) {
        httpParams = httpParams.set('organization', params.organizationId);
      }

      const data = await firstValueFrom(
        this.http.get<unknown>(this.url(ApiPaths.bookings), { params: httpParams }),
      );
      return parsePaginatedResponse(data, parseBookingListItem);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async get(id: string): Promise<BookingDetail> {
    try {
      const data = await firstValueFrom(
        this.http.get<Record<string, unknown>>(this.url(`${ApiPaths.bookings}${id}/`)),
      );
      return parseBookingDetail(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async create(payload: BookingCreatePayload): Promise<BookingDetail> {
    try {
      const data = await firstValueFrom(
        this.http.post<Record<string, unknown>>(this.url(ApiPaths.bookings), payload),
      );
      return parseBookingDetail(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async cancel(id: string, reason = ''): Promise<Record<string, unknown>> {
    try {
      const payload = await withOptionalClientLocation({ reason });
      const data = await firstValueFrom(
        this.http.post<Record<string, unknown>>(
          this.url(ApiPaths.bookingCancel(id)),
          payload,
        ),
      );
      return data ?? {};
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async confirm(id: string): Promise<BookingDetail> {
    try {
      const payload = await withOptionalClientLocation({});
      const data = await firstValueFrom(
        this.http.post<Record<string, unknown>>(
          this.url(ApiPaths.bookingConfirm(id)),
          payload,
        ),
      );
      return parseBookingDetail(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async reject(id: string, reason = ''): Promise<BookingDetail> {
    try {
      const payload = await withOptionalClientLocation({ reason });
      const data = await firstValueFrom(
        this.http.post<Record<string, unknown>>(
          this.url(ApiPaths.bookingReject(id)),
          payload,
        ),
      );
      return parseBookingDetail(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async complete(id: string): Promise<BookingDetail> {
    try {
      const payload = await withOptionalClientLocation({});
      const data = await firstValueFrom(
        this.http.post<Record<string, unknown>>(
          this.url(ApiPaths.bookingComplete(id)),
          payload,
        ),
      );
      return parseBookingDetail(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async reschedule(id: string, timeSlots: BookingTimeSlotWrite[]): Promise<void> {
    try {
      const payload = await withOptionalClientLocation({
        time_slots: timeSlots,
      });
      await firstValueFrom(
        this.http.post<void>(this.url(ApiPaths.bookingReschedule(id)), payload),
      );
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async acceptReschedule(id: string): Promise<BookingDetail> {
    try {
      const payload = await withOptionalClientLocation({});
      const data = await firstValueFrom(
        this.http.post<Record<string, unknown>>(
          this.url(ApiPaths.bookingRescheduleAccept(id)),
          payload,
        ),
      );
      return parseBookingDetail(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async declineReschedule(id: string): Promise<BookingDetail> {
    try {
      const payload = await withOptionalClientLocation({});
      const data = await firstValueFrom(
        this.http.post<Record<string, unknown>>(
          this.url(ApiPaths.bookingRescheduleDecline(id)),
          payload,
        ),
      );
      return parseBookingDetail(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }
}
