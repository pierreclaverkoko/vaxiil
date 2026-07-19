import { Component, computed, inject, input, output, signal } from '@angular/core';

import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import {
  BookingListItem,
  bookingDisplayTitle,
  earliestSlotStart,
  formatBookingListDate,
  formatBookingListTime,
  isBookingConfirmed,
  isBookingPending,
} from '@/models/booking';
import { ButtonComponent } from '@/shared/ui/button/button';
import { heroiconToMaterialSymbol } from '@/shared/ui/icon/heroicon-to-material';

@Component({
  selector: 'app-booking-list-panel',
  standalone: true,
  imports: [ButtonComponent, TranslatePipe],
  templateUrl: './booking-list-panel.html',
  styleUrl: './booking-list-panel.scss',
})
export class BookingListPanelComponent {
  private readonly locale = inject(LocaleService);

  readonly upcoming = input.required<BookingListItem[]>();
  readonly past = input.required<BookingListItem[]>();
  readonly titleFallback = input('Booking');
  /** Optional subtitle under the service title (e.g. practitioner alias). */
  readonly subtitleFor = input<(booking: BookingListItem) => string | null>(
    (booking) => booking.practitionerAlias?.trim() || null,
  );
  readonly firstTabLabel = input<string | null>(null);
  readonly secondTabLabel = input<string | null>(null);

  readonly viewDetails = output<BookingListItem>();
  readonly reschedule = output<BookingListItem>();
  readonly rebook = output<BookingListItem>();

  protected readonly segment = signal(0);

  protected readonly visibleBookings = computed(() =>
    this.segment() === 0 ? this.upcoming() : this.past(),
  );

  protected readonly emptyTabMessage = computed(() => {
    this.locale.locale();
    return this.segment() === 0
      ? this.locale.t('bookings.emptyUpcoming')
      : this.locale.t('bookings.emptyPast');
  });

  protected readonly tabUpcoming = computed(() => {
    this.locale.locale();
    return this.firstTabLabel() ?? this.locale.t('bookings.upcoming');
  });

  protected readonly tabPast = computed(() => {
    this.locale.locale();
    return this.secondTabLabel() ?? this.locale.t('bookings.past');
  });

  protected selectSegment(index: number): void {
    this.segment.set(index);
  }

  protected displayTitle(booking: BookingListItem): string {
    return bookingDisplayTitle(booking, this.titleFallback());
  }

  protected subtitle(booking: BookingListItem): string | null {
    return this.subtitleFor()(booking);
  }

  protected categoryIcon(booking: BookingListItem): string {
    return heroiconToMaterialSymbol(booking.serviceCategory?.icon);
  }

  protected isPending(booking: BookingListItem): boolean {
    return isBookingPending(booking);
  }

  protected isConfirmed(booking: BookingListItem): boolean {
    return isBookingConfirmed(booking);
  }

  protected dateLabel(booking: BookingListItem): string {
    const start = earliestSlotStart(booking) ?? booking.createdAt;
    return formatBookingListDate(start) || '—';
  }

  protected timeLabel(booking: BookingListItem): string {
    return formatBookingListTime(earliestSlotStart(booking));
  }

  protected statusTitle(booking: BookingListItem): string {
    return booking.status?.title ?? this.locale.t('bookings.detail');
  }

  protected onViewDetails(booking: BookingListItem): void {
    this.viewDetails.emit(booking);
  }

  protected onReschedule(booking: BookingListItem): void {
    this.reschedule.emit(booking);
  }

  protected onRebook(booking: BookingListItem): void {
    this.rebook.emit(booking);
  }

  protected onCheckIn(booking: BookingListItem): void {
    this.viewDetails.emit(booking);
  }
}
