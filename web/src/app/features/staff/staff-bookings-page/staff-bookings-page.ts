import { Component, OnInit, computed, inject, signal } from '@angular/core';
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
import { AdminResourceListComponent } from '@/shared/ui/admin-resource-list/admin-resource-list';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ChoiceEnumChipComponent } from '@/shared/ui/choice-enum-chip/choice-enum-chip';
import { DataTableColumn } from '@/shared/ui/data-table/data-table';

@Component({
  selector: 'app-staff-bookings-page',
  standalone: true,
  imports: [
    RouterLink,
    AdminResourceListComponent,
    ButtonComponent,
    ChoiceEnumChipComponent,
    TranslatePipe,
  ],
  templateUrl: './staff-bookings-page.html',
  styleUrl: '../staff-queue.scss',
})
export class StaffBookingsPageComponent implements OnInit {
  private readonly bookings = inject(BookingsService);
  private readonly locale = inject(LocaleService);

  protected readonly rows = signal<BookingListItem[]>([]);
  protected readonly page = signal(1);
  protected readonly totalCount = signal(0);
  protected readonly hasNext = signal(false);
  protected readonly hasPrevious = signal(false);
  protected readonly loading = signal(true);
  protected readonly loadError = signal<string | null>(null);

  protected readonly columns = computed<DataTableColumn[]>(() => {
    this.locale.locale();
    return [
      { key: 'service', label: this.locale.t('staff.colService') },
      { key: 'when', label: this.locale.t('staff.colWhen') },
      { key: 'status', label: this.locale.t('staff.colStatus') },
      { key: 'price', label: this.locale.t('staff.colPrice') },
      { key: 'actions', label: this.locale.t('staff.colActions'), width: '8rem' },
    ];
  });

  protected readonly title = (b: BookingListItem) =>
    bookingDisplayTitle(b, this.locale.t('bookings.service'));

  protected readonly when = (b: BookingListItem) => {
    const start = earliestSlotStart(b);
    return formatBookingWhen(start, b.timeSlots[0]?.endTime ?? null);
  };

  async ngOnInit(): Promise<void> {
    await this.load();
  }

  protected onPage(page: number): void {
    this.page.set(page);
    void this.load();
  }

  private async load(): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      const page = await this.bookings.listMine({ page: this.page() });
      this.rows.set(page.results);
      this.totalCount.set(page.count);
      this.hasNext.set(page.next != null);
      this.hasPrevious.set(page.previous != null);
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    } finally {
      this.loading.set(false);
    }
  }
}
