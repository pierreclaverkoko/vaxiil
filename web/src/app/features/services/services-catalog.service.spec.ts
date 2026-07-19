import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';

import { ServicesCatalogService } from './services-catalog.service';

describe('ServicesCatalogService', () => {
  let service: ServicesCatalogService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    service = TestBed.inject(ServicesCatalogService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    http.verify();
  });

  it('lists services with search, category, featured, and ordering filters', async () => {
    const promise = service.listServices({
      search: 'massage',
      categoryId: 'cat-1',
      featured: true,
      ordering: '-created_at',
      page: 1,
      pageSize: 10,
    });

    const req = http.expectOne(
      (r) =>
        r.url.includes('services/') &&
        r.method === 'GET' &&
        r.params.get('search') === 'massage' &&
        r.params.get('category') === 'cat-1' &&
        r.params.get('featured') === 'true' &&
        r.params.get('ordering') === '-created_at' &&
        r.params.get('page_size') === '10',
    );
    req.flush({
      count: 1,
      next: null,
      previous: null,
      results: [
        {
          id: 'svc-1',
          name: 'Massage',
          price_min: 50,
          price_max: 50,
          organization: { id: 'org-1', name: 'Studio' },
          sub_category: {
            id: 'sub-1',
            name: 'Massage',
            category: { id: 'cat-1', name: 'Body', icon: 'spa' },
          },
        },
      ],
    });

    const page = await promise;
    expect(page.results).toHaveLength(1);
    expect(page.results[0]?.name).toBe('Massage');
    expect(page.results[0]?.organization.id).toBe('org-1');
  });
});
