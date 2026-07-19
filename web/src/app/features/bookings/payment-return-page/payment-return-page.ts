import { Component, OnInit, inject, signal } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';

import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { BookingsService } from '@/features/bookings/bookings.service';
import { PaymentsService } from '@/features/bookings/payments.service';
import { ButtonComponent } from '@/shared/ui/button/button';

@Component({
  selector: 'app-payment-return-page',
  standalone: true,
  imports: [ButtonComponent, TranslatePipe],
  templateUrl: './payment-return-page.html',
  styleUrl: './payment-return-page.scss',
})
export class PaymentReturnPageComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly bookings = inject(BookingsService);
  private readonly payments = inject(PaymentsService);
  private readonly locale = inject(LocaleService);

  protected readonly loading = signal(true);
  protected readonly message = signal('');
  protected readonly bookingId = signal<string | null>(null);

  async ngOnInit(): Promise<void> {
    await this.resolve();
  }

  protected goToBooking(): void {
    const id = this.bookingId();
    if (id) {
      void this.router.navigate(['/bookings', id], { replaceUrl: true });
    } else {
      void this.router.navigateByUrl('/bookings', { replaceUrl: true });
    }
  }

  private async resolve(): Promise<void> {
    const qp = this.route.snapshot.queryParamMap;
    const ref = (qp.get('reference') ?? qp.get('merchant_reference') ?? '').trim();
    const status = (qp.get('status') ?? '').toLowerCase();

    if (!ref) {
      this.loading.set(false);
      this.message.set(this.locale.t('bookings.paymentReturnMissing'));
      return;
    }

    let bookingId: string | null = null;
    const parts = ref.split('_');
    if (parts.length >= 3 && parts[0] === 'bk') {
      bookingId = parts[1] ?? null;
    }

    try {
      const txn = await this.payments.getTransaction(ref);
      if (txn.bookingId) {
        bookingId = txn.bookingId;
      }
    } catch {
      // Fall back to parsed merchant reference / booking fetch.
    }

    if (bookingId) {
      try {
        await this.bookings.get(bookingId);
      } catch {
        // Still show status message.
      }
    }

    this.bookingId.set(bookingId);
    if (status === 'completed' || status === 'success') {
      this.message.set(this.locale.t('bookings.paymentReturnCompleted'));
    } else if (status === 'failed') {
      this.message.set(this.locale.t('bookings.paymentReturnFailed'));
    } else {
      this.message.set(this.locale.t('bookings.paymentReturnPending'));
    }
    this.loading.set(false);

    const purpose = (qp.get('purpose') ?? '').toLowerCase();
    const isTopUp =
      purpose === 'wallet' ||
      purpose === 'topup' ||
      purpose === 'top_up' ||
      ref.startsWith('wt_');

    if (isTopUp) {
      await new Promise((r) => setTimeout(r, 800));
      void this.router.navigateByUrl('/profile', { replaceUrl: true });
      return;
    }

    if (bookingId) {
      await new Promise((r) => setTimeout(r, 800));
      void this.router.navigate(['/bookings', bookingId], { replaceUrl: true });
    }
  }
}
