import { HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';

import { LocaleService } from '@/core/i18n/locale.service';

/** Attach Accept-Language so Django LocaleMiddleware can translate API copy. */
export const acceptLanguageInterceptor: HttpInterceptorFn = (req, next) => {
  const locale = inject(LocaleService);
  if (req.url.includes('/assets/i18n/')) {
    return next(req);
  }
  return next(
    req.clone({
      setHeaders: { 'Accept-Language': locale.acceptLanguage() },
    }),
  );
};
