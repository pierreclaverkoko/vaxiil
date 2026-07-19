import { Injectable, computed, inject, signal } from '@angular/core';

import { OrganizationsService } from '@/features/business/organizations.service';
import { Organization } from '@/models/organization';

/** Shared org list + current org for BusinessManageShell. */
@Injectable({ providedIn: 'root' })
export class OrganizationContextService {
  private readonly orgsApi = inject(OrganizationsService);

  private readonly orgsSignal = signal<Organization[]>([]);
  private readonly currentIdSignal = signal<string | null>(null);
  private readonly loadingSignal = signal(false);
  private readonly errorSignal = signal<string | null>(null);

  readonly organizations = this.orgsSignal.asReadonly();
  readonly currentOrgId = this.currentIdSignal.asReadonly();
  readonly loading = this.loadingSignal.asReadonly();
  readonly error = this.errorSignal.asReadonly();

  readonly currentOrg = computed(() => {
    const id = this.currentIdSignal();
    if (!id) {
      return null;
    }
    return this.orgsSignal().find((o) => o.id === id) ?? null;
  });

  setCurrentOrgId(id: string | null): void {
    this.currentIdSignal.set(id);
  }

  async refresh(): Promise<Organization[]> {
    this.loadingSignal.set(true);
    this.errorSignal.set(null);
    try {
      const list = await this.orgsApi.listMine();
      this.orgsSignal.set(list);
      const current = this.currentIdSignal();
      if (current && !list.some((o) => o.id === current)) {
        this.currentIdSignal.set(list[0]?.id ?? null);
      } else if (!current && list.length) {
        this.currentIdSignal.set(list[0].id);
      }
      return list;
    } catch (error) {
      this.errorSignal.set((error as { message?: string }).message ?? 'Error');
      throw error;
    } finally {
      this.loadingSignal.set(false);
    }
  }

  upsertLocal(org: Organization): void {
    const list = [...this.orgsSignal()];
    const idx = list.findIndex((o) => o.id === org.id);
    if (idx >= 0) {
      list[idx] = org;
    } else {
      list.unshift(org);
    }
    this.orgsSignal.set(list);
    this.currentIdSignal.set(org.id);
  }
}
