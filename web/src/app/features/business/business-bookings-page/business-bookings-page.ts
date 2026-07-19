import { Component, OnInit, inject, signal } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';

import { ApiError } from '@/core/http/api-error';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { BookingListPanelComponent } from '@/features/bookings/booking-list-panel/booking-list-panel';
import { BookingsService } from '@/features/bookings/bookings.service';
import {
  BookingListItem,
  sortedPastBookingList,
  sortedUpcomingBookingList,
} from '@/models/booking';
import { ButtonComponent } from '@/shared/ui/button/button';
import { EmptyStateComponent } from '@/shared/ui/empty-state/empty-state';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';

@Component({
  selector: 'app-business-bookings-page',
  standalone: true,
  imports: [
    ButtonComponent,
    BookingListPanelComponent,
    EmptyStateComponent,
    ErrorStateComponent,
    TranslatePipe,
  ],
  templateUrl: './business-bookings-page.html',
  styleUrl: './business-bookings-page.scss',
})
export class BusinessBookingsPageComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly bookings = inject(BookingsService);
  private readonly locale = inject(LocaleService);

  protected readonly orgId = signal<string | null>(null);
  protected readonly upcoming = signal<BookingListItem[]>([]);
  protected readonly past = signal<BookingListItem[]>([]);
  protected readonly loading = signal(true);
  protected readonly loadError = signal<string | null>(null);

  async ngOnInit(): Promise<void> {
    const orgId = this.route.snapshot.paramMap.get('orgId');
    this.orgId.set(orgId);
    if (!orgId) {
      this.loadError.set(this.locale.t('business.errors.missingOrgId'));
      this.loading.set(false);
      return;
    }
    await this.load(orgId);
  }

  protected onRetry(): void {
    const orgId = this.orgId();
    if (orgId) {
      void this.load(orgId);
    }
  }

  protected onViewDetails(booking: BookingListItem): void {
    const orgId = this.orgId();
    if (!orgId) {
      return;
    }
    void this.router.navigate(['/business', orgId, 'bookings', booking.id]);
  }

  protected onRebook(booking: BookingListItem): void {
    if (!booking.serviceId) {
      return;
    }
    void this.router.navigate(['/services', booking.serviceId, 'book']);
  }

  private async load(orgId: string): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      const page = await this.bookings.listMine({ organizationId: orgId });
      this.upcoming.set(sortedUpcomingBookingList(page.results));
      this.past.set(sortedPastBookingList(page.results));
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    } finally {
      this.loading.set(false);
    }
  }
}
