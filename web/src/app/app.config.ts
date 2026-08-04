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
import { countryScopeInterceptor } from '@/core/country/country-scope.interceptor';
import { CountryScopeService } from '@/core/country/country-scope.service';
import { acceptLanguageInterceptor } from '@/core/i18n/accept-language.interceptor';
import { LocaleService } from '@/core/i18n/locale.service';
import { OrganizationsService } from '@/features/business/organizations.service';
import { routes } from './app.routes';

export const appConfig: ApplicationConfig = {
  providers: [
    provideBrowserGlobalErrorListeners(),
    provideRouter(routes),
    provideHttpClient(
      withInterceptors([
        acceptLanguageInterceptor,
        countryScopeInterceptor,
        authInterceptor,
      ]),
    ),
    provideAppInitializer(() => {
      const locale = inject(LocaleService);
      const auth = inject(AuthService);
      const countryScope = inject(CountryScopeService);
      const orgs = inject(OrganizationsService);
      return locale
        .init()
        .then(() => auth.restoreSession())
        .then(async () => {
          try {
            const countries = await orgs.listCountries();
            await countryScope.ensureInitialized(countries);
          } catch {
            await countryScope.ensureInitialized([]);
          }
        });
    }),
  ],
};
