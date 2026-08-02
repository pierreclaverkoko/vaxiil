import {
  HttpErrorResponse,
  HttpInterceptorFn,
  HttpRequest,
} from '@angular/common/http';
import { inject } from '@angular/core';
import { catchError, from, switchMap, throwError } from 'rxjs';

import { ApiPaths } from '@/core/constants/api-paths';
import { AuthService } from '@/core/auth/auth.service';
import { TokenStorageService } from '@/core/auth/token-storage.service';
import { environment } from '../../../environments/environment';

const AUTH_RETRY_HEADER = 'X-Auth-Retry';

function isAuthEndpoint(url: string): boolean {
  const lower = url.toLowerCase();
  return (
    lower.includes('auth/login') ||
    lower.includes('auth/register') ||
    lower.includes('auth/token/refresh') ||
    lower.includes('auth/google')
  );
}

function refreshUrl(): string {
  return `${environment.apiBaseUrl}${ApiPaths.authTokenRefresh}`;
}

function anonymousRetry(
  outgoing: HttpRequest<unknown>,
  next: Parameters<HttpInterceptorFn>[1],
) {
  const headers = outgoing.headers.delete('Authorization').set(AUTH_RETRY_HEADER, '1');
  return next(outgoing.clone({ headers }));
}

/**
 * Attaches Bearer access token and refreshes once on 401 for safe GET retries.
 * On unrecoverable auth failure, soft-clears the local session and retries once
 * without Authorization so AllowAny guest pages keep working.
 */
export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const storage = inject(TokenStorageService);
  const auth = inject(AuthService);

  let outgoing = req;
  if (!isAuthEndpoint(req.url)) {
    const access = storage.getAccessToken();
    if (access) {
      outgoing = req.clone({
        setHeaders: { Authorization: `Bearer ${access}` },
      });
    }
  }

  return next(outgoing).pipe(
    catchError((error: unknown) => {
      if (!(error instanceof HttpErrorResponse) || error.status !== 401) {
        return throwError(() => error);
      }
      if (outgoing.headers.has(AUTH_RETRY_HEADER) || isAuthEndpoint(outgoing.url)) {
        return throwError(() => error);
      }

      const softDisconnectAndRetry = () => {
        auth.clearLocalSession();
        return anonymousRetry(outgoing, next);
      };

      const refresh = storage.getRefreshToken();
      if (!refresh) {
        return softDisconnectAndRetry();
      }

      return from(
        fetch(refreshUrl(), {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Accept: 'application/json',
          },
          body: JSON.stringify({ refresh }),
        }).then(async (response) => {
          if (!response.ok) {
            if (
              response.status === 400 ||
              response.status === 401 ||
              response.status === 403
            ) {
              return { kind: 'soft' as const };
            }
            // Unexpected refresh failure — keep tokens, surface original 401.
            throw error;
          }
          const data = (await response.json()) as { access?: string; refresh?: string };
          if (!data.access) {
            return { kind: 'soft' as const };
          }
          storage.saveTokens(data.access, data.refresh ?? refresh);
          return { kind: 'refreshed' as const, access: data.access };
        }),
      ).pipe(
        switchMap((result) => {
          if (result.kind === 'soft') {
            return softDisconnectAndRetry();
          }
          if (outgoing.method.toUpperCase() !== 'GET') {
            return throwError(() => error);
          }
          const retry: HttpRequest<unknown> = outgoing.clone({
            setHeaders: {
              Authorization: `Bearer ${result.access}`,
              [AUTH_RETRY_HEADER]: '1',
            },
          });
          return next(retry);
        }),
        catchError((err: unknown) => {
          // Network / unexpected refresh errors: soft-disconnect for guest UX.
          if (err === error) {
            return throwError(() => error);
          }
          return softDisconnectAndRetry();
        }),
      );
    }),
  );
};
