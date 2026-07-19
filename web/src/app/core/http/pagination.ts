import { DEFAULT_PAGE_SIZE, MAX_PAGE_SIZE } from '@/core/constants/api-paths';

export interface PaginatedResponse<T> {
  count: number;
  next: string | null;
  previous: string | null;
  results: T[];
}

export interface PageParams {
  page?: number;
  pageSize?: number;
}

/** Raw JSON list rows from a GET response body (DRF paginated or plain array). */
export function jsonListFromResponse(data: unknown): unknown[] {
  if (data == null) {
    return [];
  }
  if (Array.isArray(data)) {
    return data;
  }
  if (typeof data === 'object') {
    const results = (data as Record<string, unknown>)['results'];
    if (Array.isArray(results)) {
      return results;
    }
  }
  return [];
}

export function parseJsonList<T>(
  responseData: unknown,
  fromJson: (json: Record<string, unknown>) => T,
): T[] {
  return jsonListFromResponse(responseData).map((element) => {
    if (!element || typeof element !== 'object' || Array.isArray(element)) {
      throw new Error(`Expected JSON object in list, got ${typeof element}`);
    }
    return fromJson(element as Record<string, unknown>);
  });
}

export function parsePaginatedResponse<T>(
  data: unknown,
  fromJson: (json: Record<string, unknown>) => T,
): PaginatedResponse<T> {
  if (Array.isArray(data)) {
    const results = parseJsonList(data, fromJson);
    return { count: results.length, next: null, previous: null, results };
  }
  if (data && typeof data === 'object') {
    const body = data as Record<string, unknown>;
    const results = parseJsonList(body, fromJson);
    return {
      count: typeof body['count'] === 'number' ? body['count'] : results.length,
      next: typeof body['next'] === 'string' ? body['next'] : null,
      previous: typeof body['previous'] === 'string' ? body['previous'] : null,
      results,
    };
  }
  return { count: 0, next: null, previous: null, results: [] };
}

export function toPageQuery(params: PageParams = {}): Record<string, string | number> {
  const page = Math.max(1, params.page ?? 1);
  const pageSize = Math.min(MAX_PAGE_SIZE, Math.max(1, params.pageSize ?? DEFAULT_PAGE_SIZE));
  return { page, page_size: pageSize };
}

export function hasMorePages(page: Pick<PaginatedResponse<unknown>, 'next'>): boolean {
  return page.next != null;
}
