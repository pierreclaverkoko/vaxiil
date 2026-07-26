import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';

import { ApiPaths } from '@/core/constants/api-paths';
import { mapHttpError } from '@/core/http/api-error';
import { PaginatedResponse, parsePaginatedResponse, toPageQuery } from '@/core/http/pagination';
import { LocaleService } from '@/core/i18n/locale.service';
import {
  ConversationInvite,
  ConversationMessage,
  ConversationSummary,
  parseConversationInvite,
  parseConversationMessage,
  parseConversationSummary,
} from '@/models/messaging';
import { environment } from '../../../environments/environment';

@Injectable({ providedIn: 'root' })
export class MessagingService {
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

  async listConversations(
    params: { page?: number; pageSize?: number; organizationId?: string } = {},
  ): Promise<PaginatedResponse<ConversationSummary>> {
    try {
      let httpParams = new HttpParams();
      const pageQuery = toPageQuery(params);
      for (const [key, value] of Object.entries(pageQuery)) {
        httpParams = httpParams.set(key, String(value));
      }
      if (params.organizationId) {
        httpParams = httpParams.set('organization_id', params.organizationId);
      }
      const data = await firstValueFrom(
        this.http.get<unknown>(this.url(ApiPaths.messagingConversations), {
          params: httpParams,
        }),
      );
      return parsePaginatedResponse(data, parseConversationSummary);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async getConversation(id: string): Promise<ConversationSummary> {
    try {
      const data = await firstValueFrom(
        this.http.get<unknown>(this.url(ApiPaths.messagingConversation(id))),
      );
      return parseConversationSummary(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async listMessages(
    conversationId: string,
    opts: { since?: string } = {},
  ): Promise<ConversationMessage[]> {
    try {
      let httpParams = new HttpParams();
      if (opts.since) {
        httpParams = httpParams.set('since', opts.since);
      }
      const data = await firstValueFrom(
        this.http.get<{ results?: unknown[] }>(
          this.url(ApiPaths.messagingMessages(conversationId)),
          { params: httpParams },
        ),
      );
      const rows = Array.isArray(data?.results) ? data.results : [];
      return rows.map(parseConversationMessage);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async sendMessage(conversationId: string, body: string): Promise<ConversationMessage> {
    try {
      const data = await firstValueFrom(
        this.http.post<unknown>(this.url(ApiPaths.messagingMessages(conversationId)), {
          body,
        }),
      );
      return parseConversationMessage(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async markRead(conversationId: string): Promise<void> {
    try {
      await firstValueFrom(
        this.http.post(this.url(ApiPaths.messagingRead(conversationId)), {}),
      );
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async block(conversationId: string): Promise<ConversationSummary> {
    try {
      const data = await firstValueFrom(
        this.http.post<unknown>(this.url(ApiPaths.messagingBlock(conversationId)), {}),
      );
      return parseConversationSummary(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async unblock(conversationId: string): Promise<ConversationSummary> {
    try {
      const data = await firstValueFrom(
        this.http.post<unknown>(this.url(ApiPaths.messagingUnblock(conversationId)), {}),
      );
      return parseConversationSummary(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async openBookingThread(bookingId: string): Promise<ConversationSummary> {
    try {
      const data = await firstValueFrom(
        this.http.post<unknown>(this.url(ApiPaths.messagingBookingThread), {
          booking_id: bookingId,
        }),
      );
      return parseConversationSummary(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async openSupportThread(organizationId: string): Promise<ConversationSummary> {
    try {
      const data = await firstValueFrom(
        this.http.post<unknown>(this.url(ApiPaths.messagingSupportThread), {
          organization_id: organizationId,
        }),
      );
      return parseConversationSummary(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async openPlatformSupport(userId?: string): Promise<ConversationSummary> {
    try {
      const body = userId ? { user_id: userId } : {};
      const data = await firstValueFrom(
        this.http.post<unknown>(this.url(ApiPaths.messagingPlatformSupportThread), body),
      );
      return parseConversationSummary(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async submitInvite(payload: {
    email?: string;
    phone?: string;
    trustAlias?: string;
  }): Promise<string> {
    try {
      const body: Record<string, string> = {};
      if (payload.email) {
        body['email'] = payload.email;
      }
      if (payload.phone) {
        body['phone'] = payload.phone;
      }
      if (payload.trustAlias) {
        body['trust_alias'] = payload.trustAlias;
      }
      const data = await firstValueFrom(
        this.http.post<{ detail?: string }>(this.url(ApiPaths.messagingInvites), body),
      );
      return typeof data.detail === 'string' ? data.detail : this.locale.t('messages.inviteAck');
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async listIncomingInvites(): Promise<ConversationInvite[]> {
    try {
      const data = await firstValueFrom(
        this.http.get<unknown>(this.url(ApiPaths.messagingInvitesIncoming)),
      );
      const rows = Array.isArray(data) ? data : [];
      return rows.map(parseConversationInvite);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async acceptInvite(id: string): Promise<ConversationSummary> {
    try {
      const data = await firstValueFrom(
        this.http.post<unknown>(this.url(ApiPaths.messagingInviteAccept(id)), {}),
      );
      return parseConversationSummary(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async declineInvite(id: string, block = false): Promise<void> {
    try {
      await firstValueFrom(
        this.http.post(this.url(ApiPaths.messagingInviteDecline(id)), { block }),
      );
    } catch (error) {
      throw this.mapError(error);
    }
  }
}
