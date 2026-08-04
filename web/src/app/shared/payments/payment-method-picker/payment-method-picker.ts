import {
  Component,
  OnChanges,
  OnInit,
  SimpleChanges,
  inject,
  input,
  output,
  signal,
} from '@angular/core';

import { TranslatePipe } from '@/core/i18n/translate.pipe';
import {
  PaymentCatalogService,
  PaymentMethodBrief,
  PaymentOperation,
} from '@/shared/payments/payment-catalog.service';

@Component({
  selector: 'app-payment-method-picker',
  standalone: true,
  imports: [TranslatePipe],
  templateUrl: './payment-method-picker.html',
  styleUrl: './payment-method-picker.scss',
})
export class PaymentMethodPickerComponent implements OnInit, OnChanges {
  private readonly catalog = inject(PaymentCatalogService);

  readonly operation = input<PaymentOperation>('settlement');
  readonly country = input<string | null>(null);
  /** When set, filters methods to this type (B/M/F/C) and hides type chips. */
  readonly methodType = input<string | null>(null);
  readonly selectedMethodId = input<string | null>(null);
  readonly showTypeChips = input(true);

  readonly selectionChange = output<PaymentMethodBrief | null>();

  protected readonly query = signal('');
  protected readonly typeFilter = signal<string>('');
  protected readonly loading = signal(false);
  protected readonly methods = signal<PaymentMethodBrief[]>([]);
  protected readonly error = signal<string | null>(null);

  private debounce: ReturnType<typeof setTimeout> | null = null;
  private initialized = false;

  ngOnInit(): void {
    this.initialized = true;
    void this.reload();
  }

  ngOnChanges(changes: SimpleChanges): void {
    if (!this.initialized) {
      return;
    }
    if (
      changes['operation'] ||
      changes['country'] ||
      changes['methodType'] ||
      changes['showTypeChips']
    ) {
      void this.reload();
    }
  }

  protected onQuery(event: Event): void {
    const value = (event.target as HTMLInputElement).value;
    this.query.set(value);
    if (this.debounce) clearTimeout(this.debounce);
    this.debounce = setTimeout(() => void this.reload(), 250);
  }

  protected setType(type: string): void {
    this.typeFilter.set(this.typeFilter() === type ? '' : type);
    void this.reload();
  }

  protected pick(method: PaymentMethodBrief): void {
    this.selectionChange.emit(method);
  }

  private async reload(): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    try {
      const forcedType = this.methodType();
      const rows = await this.catalog.listMethods({
        q: this.query() || undefined,
        country: this.country() || undefined,
        methodType: forcedType || this.typeFilter() || undefined,
        operation: this.operation(),
      });
      this.methods.set(rows);
    } catch {
      this.error.set('payments.picker.loadError');
      this.methods.set([]);
    } finally {
      this.loading.set(false);
    }
  }
}
