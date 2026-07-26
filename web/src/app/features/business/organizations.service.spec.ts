import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';

import { OrganizationsService } from '@/features/business/organizations.service';
import { LocaleService } from '@/core/i18n/locale.service';

describe('OrganizationsService', () => {
  let service: OrganizationsService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(),
        provideHttpClientTesting(),
        {
          provide: LocaleService,
          useValue: {
            t: (key: string) => key,
            acceptLanguage: () => 'en',
          },
        },
      ],
    });
    service = TestBed.inject(OrganizationsService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    http.verify();
  });

  it('lists mine organizations', async () => {
    const promise = service.listMine();
    const req = http.expectOne((r) => r.url.includes('organizations/') && !r.url.includes('mine'));
    expect(req.request.method).toBe('GET');
    req.flush([
      {
        id: 'org-1',
        name: 'Zen Spa',
        type: 't1',
        email: 'z@example.com',
        address: '1 St',
        city: { id: 7, name: 'Town' },
        postal_code: '00000',
        country: { id: 'c1', name: 'US', iso_code2: 'US' },
        verification_status: { value: 'V', title: 'Verified', css: 'success' },
      },
    ]);
    const list = await promise;
    expect(list.length).toBe(1);
    expect(list[0].name).toBe('Zen Spa');
    expect(list[0].city).toBe('Town');
    expect(list[0].cityId).toBe('7');
    expect(list[0].verificationStatus?.value).toBe('V');
  });

  it('lists cities for a country', async () => {
    const promise = service.listCities('country-1', 'Sea');
    const req = http.expectOne(
      (r) =>
        r.url.includes('organizations/cities/') &&
        r.method === 'GET' &&
        r.params.get('country') === 'country-1' &&
        r.params.get('q') === 'Sea',
    );
    req.flush([{ id: 1, name: 'Seattle' }]);
    const cities = await promise;
    expect(cities).toHaveLength(1);
    expect(cities[0].name).toBe('Seattle');
  });

  it('loads mine summary', async () => {
    const promise = service.mineSummary();
    const req = http.expectOne((r) => r.url.includes('mine-summary'));
    req.flush({ organization_count: 2, collective_beneficiaries: 10 });
    const summary = await promise;
    expect(summary.organizationCount).toBe(2);
    expect(summary.collectiveBeneficiaries).toBe(10);
  });
});
