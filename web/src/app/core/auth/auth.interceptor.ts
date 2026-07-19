import {
  HttpErrorResponse,
  HttpInterceptorFn,
  HttpRequest,
} from '@angular/common/http';
import { inject } from '@angular/core';
import { catchError, from, switchMap, throwError } from 'rxjs';

import { ApiPaths } from '@/core/constants/api-paths';
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

/**
 * Attaches Bearer access token and refreshes once on 401 for safe GET retries
 * (parity with Flutter AuthInterceptor).
 */
export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const storage = inject(TokenStorageService);

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

      const refresh = storage.getRefreshToken();
      if (!refresh) {
        return throwError(() => error);
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
            if (response.status === 400 || response.status === 403) {
              storage.clearSession();
            }
            throw error;
          }
          const data = (await response.json()) as { access?: string; refresh?: string };
          if (!data.access) {
            throw error;
          }
          storage.saveTokens(data.access, data.refresh ?? refresh);
          return data.access;
        }),
      ).pipe(
        switchMap((newAccess) => {
          if (outgoing.method.toUpperCase() !== 'GET') {
            return throwError(() => error);
          }
          const retry: HttpRequest<unknown> = outgoing.clone({
            setHeaders: {
              Authorization: `Bearer ${newAccess}`,
              [AUTH_RETRY_HEADER]: '1',
            },
          });
          return next(retry);
        }),
        catchError(() => throwError(() => error)),
      );
    }),
  );
};
