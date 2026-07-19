import { Component, OnInit, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { ApiError } from '@/core/http/api-error';
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
  selector: 'app-bookings-list-page',
  standalone: true,
  imports: [
    ButtonComponent,
    BookingListPanelComponent,
    EmptyStateComponent,
    ErrorStateComponent,
    TranslatePipe,
  ],
  templateUrl: './bookings-list-page.html',
  styleUrl: './bookings-list-page.scss',
})
export class BookingsListPageComponent implements OnInit {
  private readonly bookings = inject(BookingsService);
  private readonly router = inject(Router);

  protected readonly upcoming = signal<BookingListItem[]>([]);
  protected readonly past = signal<BookingListItem[]>([]);
  protected readonly loading = signal(true);
  protected readonly loadError = signal<string | null>(null);

  async ngOnInit(): Promise<void> {
    await this.load();
  }

  protected onRetry(): void {
    void this.load();
  }

  protected onDiscover(): void {
    void this.router.navigateByUrl('/discover');
  }

  protected onViewDetails(booking: BookingListItem): void {
    void this.router.navigate(['/bookings', booking.id]);
  }

  protected onRebook(booking: BookingListItem): void {
    if (!booking.serviceId) {
      return;
    }
    void this.router.navigate(['/services', booking.serviceId, 'book']);
  }

  private async load(): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      const page = await this.bookings.listMine();
      this.upcoming.set(sortedUpcomingBookingList(page.results));
      this.past.set(sortedPastBookingList(page.results));
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    } finally {
      this.loading.set(false);
    }
  }
}
