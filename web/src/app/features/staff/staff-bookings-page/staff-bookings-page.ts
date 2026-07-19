import { Component, OnInit, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';

import { ApiError } from '@/core/http/api-error';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { BookingsService } from '@/features/bookings/bookings.service';
import {
  BookingListItem,
  bookingDisplayTitle,
  earliestSlotStart,
  formatBookingWhen,
} from '@/models/booking';
import { ChoiceEnumChipComponent } from '@/shared/ui/choice-enum-chip/choice-enum-chip';
import { DataTableComponent, DataTableColumn } from '@/shared/ui/data-table/data-table';
import { EmptyStateComponent } from '@/shared/ui/empty-state/empty-state';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';

@Component({
  selector: 'app-staff-bookings-page',
  standalone: true,
  imports: [
    RouterLink,
    ChoiceEnumChipComponent,
    DataTableComponent,
    EmptyStateComponent,
    ErrorStateComponent,
    TranslatePipe,
  ],
  templateUrl: './staff-bookings-page.html',
  styleUrl: '../staff-queue.scss',
})
export class StaffBookingsPageComponent implements OnInit {
  private readonly bookings = inject(BookingsService);
  private readonly locale = inject(LocaleService);

  protected readonly rows = signal<BookingListItem[]>([]);
  protected readonly loading = signal(true);
  protected readonly loadError = signal<string | null>(null);

  protected readonly columns: DataTableColumn[] = [
    { key: 'service', label: 'Service' },
    { key: 'when', label: 'When' },
    { key: 'status', label: 'Status' },
    { key: 'price', label: 'Price' },
  ];

  protected readonly title = (b: BookingListItem) =>
    bookingDisplayTitle(b, this.locale.t('bookings.service'));

  protected readonly when = (b: BookingListItem) => {
    const start = earliestSlotStart(b);
    return formatBookingWhen(start, b.timeSlots[0]?.endTime ?? null);
  };

  async ngOnInit(): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      const page = await this.bookings.listMine({ page: 1 });
      this.rows.set(page.results);
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    } finally {
      this.loading.set(false);
    }
  }
}
