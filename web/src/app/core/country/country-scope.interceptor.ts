import { HttpEventType, HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { tap } from 'rxjs/operators';

import {
  CountryScopeService,
  RESOLVED_COUNTRY_HEADER,
} from '@/core/country/country-scope.service';

/** Attach X-Timezone / X-Country; hydrate scope from X-Resolved-Country when empty. */
export const countryScopeInterceptor: HttpInterceptorFn = (req, next) => {
  const scope = inject(CountryScopeService);
  if (req.url.includes('/assets/i18n/')) {
    return next(req);
  }

  const headers: Record<string, string> = {
    'X-Timezone': scope.browserTimezone(),
  };
  const iso = scope.isoCode2();
  if (iso) {
    headers['X-Country'] = iso;
  }

  return next(req.clone({ setHeaders: headers })).pipe(
    tap((event) => {
      if (event.type !== HttpEventType.Response) {
        return;
      }
      const resolved = event.headers.get(RESOLVED_COUNTRY_HEADER);
      scope.hydrateFromResolvedHeader(resolved);
    }),
  );
};
