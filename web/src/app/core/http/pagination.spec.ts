import { hasMorePages, jsonListFromResponse, parsePaginatedResponse, toPageQuery } from './pagination';

describe('pagination helpers', () => {
  it('reads DRF results', () => {
    expect(jsonListFromResponse({ count: 1, next: null, previous: null, results: [{ id: 1 }] })).toEqual([
      { id: 1 },
    ]);
  });

  it('reads bare arrays', () => {
    expect(jsonListFromResponse([{ id: 2 }])).toEqual([{ id: 2 }]);
  });

  it('parses paginated response', () => {
    const page = parsePaginatedResponse(
      { count: 2, next: 'http://x?page=2', previous: null, results: [{ id: 'a' }] },
      (json) => ({ id: String(json['id']) }),
    );
    expect(page.count).toBe(2);
    expect(page.results).toEqual([{ id: 'a' }]);
    expect(hasMorePages(page)).toBe(true);
  });

  it('builds page query params', () => {
    expect(toPageQuery({ page: 2, pageSize: 50 })).toEqual({ page: 2, page_size: 50 });
  });
});
