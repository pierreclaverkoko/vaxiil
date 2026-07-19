import { provideHttpClient, withInterceptors } from '@angular/common/http';
import {
  ApplicationConfig,
  inject,
  provideAppInitializer,
  provideBrowserGlobalErrorListeners,
} from '@angular/core';
import { provideRouter } from '@angular/router';

import { AuthService } from '@/core/auth/auth.service';
import { authInterceptor } from '@/core/auth/auth.interceptor';
import { acceptLanguageInterceptor } from '@/core/i18n/accept-language.interceptor';
import { LocaleService } from '@/core/i18n/locale.service';
import { routes } from './app.routes';

export const appConfig: ApplicationConfig = {
  providers: [
    provideBrowserGlobalErrorListeners(),
    provideRouter(routes),
    provideHttpClient(
      withInterceptors([acceptLanguageInterceptor, authInterceptor]),
    ),
    provideAppInitializer(() => {
      const locale = inject(LocaleService);
      const auth = inject(AuthService);
      return locale.init().then(() => auth.restoreSession());
    }),
  ],
};
