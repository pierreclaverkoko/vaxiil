import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import type { ChartConfiguration } from 'chart.js';

import { ApiError } from '@/core/http/api-error';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { StaffApiService, StaffOverview } from '@/features/staff/staff-api.service';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ChartCanvasComponent } from '@/shared/ui/chart-canvas/chart-canvas';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';

@Component({
  selector: 'app-staff-home-page',
  standalone: true,
  imports: [
    RouterLink,
    TranslatePipe,
    ButtonComponent,
    ChartCanvasComponent,
    ErrorStateComponent,
  ],
  templateUrl: './staff-home-page.html',
  styleUrl: './staff-home-page.scss',
})
export class StaffHomePageComponent implements OnInit {
  private readonly api = inject(StaffApiService);

  protected readonly overview = signal<StaffOverview | null>(null);
  protected readonly loading = signal(true);
  protected readonly loadError = signal<string | null>(null);

  protected readonly links = [
    { path: '/staff/users', labelKey: 'shell.staff.users', icon: 'badge' },
    { path: '/staff/organizations', labelKey: 'shell.staff.organizations', icon: 'domain' },
    { path: '/staff/taxonomy', labelKey: 'shell.staff.taxonomy', icon: 'category' },
    { path: '/staff/bookings', labelKey: 'shell.staff.bookings', icon: 'event_note' },
    { path: '/staff/payments', labelKey: 'shell.staff.payments', icon: 'payments' },
    { path: '/staff/fees', labelKey: 'shell.staff.fees', icon: 'percent' },
    { path: '/staff/settlements', labelKey: 'shell.staff.settlements', icon: 'account_balance_wallet' },
  ] as const;

  protected readonly bookingLabels = computed(
    () => this.overview()?.bookingsLast14Days.map((d) => d.date.slice(5)) ?? [],
  );
  protected readonly bookingDatasets = computed<ChartConfiguration['data']['datasets']>(() => [
    {
      data: this.overview()?.bookingsLast14Days.map((d) => d.count) ?? [],
      borderColor: '#1b5e20',
      backgroundColor: 'rgba(46, 125, 50, 0.15)',
      fill: true,
      tension: 0.35,
      pointRadius: 0,
    },
  ]);

  protected readonly paymentLabels = computed(
    () => this.overview()?.paymentsLast14Days.map((d) => d.date.slice(5)) ?? [],
  );
  protected readonly paymentDatasets = computed<ChartConfiguration['data']['datasets']>(() => [
    {
      data: this.overview()?.paymentsLast14Days.map((d) => d.count) ?? [],
      backgroundColor: '#0d631b',
      borderRadius: 6,
    },
  ]);

  protected readonly netFeesLabel = computed(() => {
    const fees = this.overview()?.feesByCurrency ?? [];
    if (!fees.length) {
      return '—';
    }
    return fees.map((f) => `${f.netFees} ${f.currency}`).join(' · ');
  });

  async ngOnInit(): Promise<void> {
    await this.load();
  }

  protected async load(): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      this.overview.set(await this.api.getOverview());
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    } finally {
      this.loading.set(false);
    }
  }
}
