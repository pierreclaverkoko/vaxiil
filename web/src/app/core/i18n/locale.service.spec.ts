import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';

import { LocaleService } from '@/core/i18n/locale.service';

describe('LocaleService', () => {
  let service: LocaleService;
  let http: HttpTestingController;

  beforeEach(() => {
    localStorage.clear();
    TestBed.configureTestingModule({
      providers: [provideHttpClient(), provideHttpClientTesting(), LocaleService],
    });
    service = TestBed.inject(LocaleService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    http.verify();
    localStorage.clear();
  });

  it('loads catalog and translates keys', async () => {
    const init = service.init();
    http.expectOne('/assets/i18n/en.json').flush({
      common: { signIn: 'Sign in' },
    });
    await init;
    expect(service.t('common.signIn')).toBe('Sign in');
  });

  it('switches to French and interpolates', async () => {
    const init = service.init();
    http.expectOne('/assets/i18n/en.json').flush({
      services: { minutes: '{{count}} min' },
    });
    await init;

    const switchPromise = service.setLocale('fr');
    http.expectOne('/assets/i18n/fr.json').flush({
      services: { minutes: '{{count}} min' },
    });
    await switchPromise;
    expect(service.locale()).toBe('fr');
    expect(service.t('services.minutes', { count: 45 })).toBe('45 min');
  });
});
