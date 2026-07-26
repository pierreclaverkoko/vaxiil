import { HttpClient } from '@angular/common/http';
import { Injectable, inject, signal } from '@angular/core';
import { firstValueFrom } from 'rxjs';

export type AppLocale = 'en' | 'fr';

type Dict = Record<string, unknown>;

const STORAGE_KEY = 'vaxiil.locale';

@Injectable({ providedIn: 'root' })
export class LocaleService {
  private readonly http = inject(HttpClient);

  private readonly catalogs = signal<Partial<Record<AppLocale, Dict>>>({});
  readonly locale = signal<AppLocale>(this.readStored());

  acceptLanguage(): string {
    return this.locale();
  }

  async init(): Promise<void> {
    const code = this.locale();
    try {
      await this.ensureLoaded(code);
    } catch (err) {
      // Do not block app bootstrap (blank shell / no redirects) on catalog load failure.
      console.error('Failed to load i18n catalog', code, err);
    }
    this.applyDocumentLang(code);
  }

  async setLocale(code: AppLocale): Promise<void> {
    await this.ensureLoaded(code);
    this.locale.set(code);
    localStorage.setItem(STORAGE_KEY, code);
    this.applyDocumentLang(code);
  }

  /** Resolve a dotted key; optional `{{name}}` params. Falls back to key. */
  t(key: string, params?: Record<string, string | number>): string {
    const dict = this.catalogs()[this.locale()] ?? this.catalogs()['en'];
    let value = this.lookup(dict, key);
    if (value == null && this.locale() !== 'en') {
      value = this.lookup(this.catalogs()['en'], key);
    }
    if (value == null) {
      return key;
    }
    if (!params) {
      return value;
    }
    return value.replace(/\{\{(\w+)\}\}/g, (_, name: string) =>
      params[name] != null ? String(params[name]) : '',
    );
  }

  private readStored(): AppLocale {
    const raw = localStorage.getItem(STORAGE_KEY);
    return raw === 'fr' ? 'fr' : 'en';
  }

  private applyDocumentLang(code: AppLocale): void {
    if (typeof document !== 'undefined') {
      document.documentElement.lang = code;
    }
  }

  private async ensureLoaded(code: AppLocale): Promise<void> {
    if (this.catalogs()[code]) {
      return;
    }
    const data = await firstValueFrom(
      this.http.get<Dict>(`/assets/i18n/${code}.json`),
    );
    this.catalogs.update((c) => ({ ...c, [code]: data }));
  }

  private lookup(dict: Dict | undefined, key: string): string | null {
    if (!dict) {
      return null;
    }
    const parts = key.split('.');
    let cur: unknown = dict;
    for (const part of parts) {
      if (!cur || typeof cur !== 'object') {
        return null;
      }
      cur = (cur as Dict)[part];
    }
    return typeof cur === 'string' ? cur : null;
  }
}
