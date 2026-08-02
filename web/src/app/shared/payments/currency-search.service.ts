import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { firstValueFrom } from 'rxjs';

import { environment } from '../../../environments/environment';
import type { AutocompleteOption } from '@/shared/ui/autocomplete-field/autocomplete-field';

export interface CurrencyRow {
  id: string;
  code: string;
  name: string;
  symbol: string;
}

@Injectable({ providedIn: 'root' })
export class CurrencySearchService {
  private readonly http = inject(HttpClient);

  private url(path: string): string {
    return `${environment.apiBaseUrl}${path}`;
  }

  async search(q: string): Promise<CurrencyRow[]> {
    let params = new HttpParams();
    const trimmed = q.trim();
    if (trimmed) {
      params = params.set('q', trimmed);
    }
    const data = await firstValueFrom(
      this.http.get<unknown>(this.url('finances/currencies/'), { params }),
    );
    const rows = Array.isArray(data)
      ? data
      : data && typeof data === 'object' && Array.isArray((data as { results?: unknown }).results)
        ? ((data as { results: unknown[] }).results)
        : [];
    return rows
      .filter((r): r is Record<string, unknown> => !!r && typeof r === 'object')
      .map((r) => ({
        id: String(r['id'] ?? r['code'] ?? ''),
        code: typeof r['code'] === 'string' ? r['code'] : '',
        name: typeof r['name'] === 'string' ? r['name'] : '',
        symbol: typeof r['symbol'] === 'string' ? r['symbol'] : '',
      }))
      .filter((r) => r.code);
  }

  async toAutocompleteOptions(q: string): Promise<AutocompleteOption[]> {
    const rows = await this.search(q);
    return rows.map((r) => ({
      id: r.code,
      label: `${r.code} — ${r.name}`,
      description: r.symbol || undefined,
    }));
  }
}
