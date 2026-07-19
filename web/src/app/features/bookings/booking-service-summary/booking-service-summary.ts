import { Component, input } from '@angular/core';

import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { BookingDetail, BookingListItem } from '@/models/booking';
import { ServiceDetail, formatServicePrice } from '@/models/service-catalog';

@Component({
  selector: 'app-booking-service-summary',
  standalone: true,
  imports: [TranslatePipe],
  templateUrl: './booking-service-summary.html',
  styleUrl: './booking-service-summary.scss',
})
export class BookingServiceSummaryComponent {
  /** Catalog service detail when loaded. */
  readonly service = input<ServiceDetail | null>(null);
  /** Booking for fallbacks (name, category, org, price). */
  readonly booking = input<BookingDetail | BookingListItem | null>(null);
  /** Optional price line override (e.g. schedule summary). */
  readonly priceLabel = input<string | null>(null);
  /** Compact layout without hero image. */
  readonly compact = input(false);

  protected readonly formatPrice = formatServicePrice;

  protected displayName(): string {
    return this.service()?.name || this.booking()?.serviceName || '';
  }

  protected description(): string {
    const d = this.service()?.description?.trim() ?? '';
    return d;
  }

  protected primaryImage(): string | null {
    return this.service()?.primaryImage ?? null;
  }

  protected organizationName(): string {
    return (
      this.service()?.organization.name ||
      (this.booking() as BookingDetail | null)?.organizationName ||
      ''
    );
  }

  protected categoryName(): string {
    return this.service()?.subCategory.category.name || this.booking()?.serviceCategory?.name || '';
  }

  protected categoryIcon(): string {
    return (
      this.service()?.subCategory.category.icon || this.booking()?.serviceCategory?.icon || 'spa'
    );
  }

  protected priceText(): string | null {
    const override = this.priceLabel();
    if (override) {
      return override;
    }
    const b = this.booking();
    if (!b?.totalPrice) {
      return null;
    }
    const amount = Number(b.totalPrice);
    if (!Number.isFinite(amount)) {
      return b.totalPrice;
    }
    return formatServicePrice(amount, b.currencyCode || 'USD');
  }
}
