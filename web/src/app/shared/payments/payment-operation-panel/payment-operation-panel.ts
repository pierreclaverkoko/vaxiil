import { Component, computed, effect, inject, input, output, signal } from '@angular/core';

import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { CurrencySearchService } from '@/shared/payments/currency-search.service';
import {
  PaymentMethodBrief,
  PaymentOperation,
  PaymentOperationPayload,
} from '@/shared/payments/payment-catalog.service';
import { PaymentMethodPickerComponent } from '@/shared/payments/payment-method-picker/payment-method-picker';
import {
  AutocompleteFieldComponent,
  AutocompleteOption,
} from '@/shared/ui/autocomplete-field/autocomplete-field';
import { ButtonComponent } from '@/shared/ui/button/button';
import { InputComponent } from '@/shared/ui/input/input';

@Component({
  selector: 'app-payment-operation-panel',
  standalone: true,
  imports: [
    AutocompleteFieldComponent,
    ButtonComponent,
    InputComponent,
    PaymentMethodPickerComponent,
    TranslatePipe,
  ],
  templateUrl: './payment-operation-panel.html',
  styleUrl: './payment-operation-panel.scss',
})
export class PaymentOperationPanelComponent {
  private readonly currencies = inject(CurrencySearchService);
  private readonly locale = inject(LocaleService);

  readonly operation = input<PaymentOperation>('business_payout');
  readonly country = input<string | null>(null);
  /** Skip picker when method already known. */
  readonly methodKnown = input<PaymentMethodBrief | null>(null);
  /** Skip destination fields when account already saved. */
  readonly destinationKnown = input(false);
  readonly settlementAccountId = input<string | null>(null);
  readonly fixedCurrencyCode = input<string | null>(null);
  readonly showAmount = input(true);
  readonly submitLabelKey = input('payments.panel.submit');
  readonly busy = input(false);

  readonly submitted = output<PaymentOperationPayload>();

  protected readonly selectedMethod = signal<PaymentMethodBrief | null>(null);
  protected readonly accountIdentifier = signal('');
  protected readonly accountName = signal('');
  protected readonly detailValues = signal<Record<string, string>>({});
  protected readonly amount = signal('');
  protected readonly currencyCode = signal('');
  protected readonly currencyOptions = signal<AutocompleteOption[]>([]);
  protected readonly currencyQuery = signal('');
  protected readonly currencyLoading = signal(false);
  protected readonly localError = signal<string | null>(null);

  protected readonly effectiveMethod = computed(
    () => this.methodKnown() ?? this.selectedMethod(),
  );

  protected readonly showPicker = computed(() => !this.methodKnown());
  protected readonly showDestination = computed(
    () => !this.destinationKnown() && !!this.effectiveMethod(),
  );
  protected readonly showCurrencyPicker = computed(
    () => this.showAmount() && !this.fixedCurrencyCode(),
  );

  protected readonly destinationFieldKeys = computed(() => {
    const method = this.effectiveMethod();
    if (!method) return [] as string[];
    return method.destinationFields.filter(
      (f) =>
        ![
          'iban',
          'phone_number',
          'interac_email',
          'account_number',
          'account_identifier',
          'account_holder_name',
          'account_name',
          'destination_name',
        ].includes(f),
    );
  });

  constructor() {
    effect(() => {
      const fixed = this.fixedCurrencyCode();
      if (fixed) {
        this.currencyCode.set(fixed);
      }
    });
  }

  protected onMethodSelected(method: PaymentMethodBrief | null): void {
    this.selectedMethod.set(method);
    this.localError.set(null);
  }

  protected async onCurrencyQuery(q: string): Promise<void> {
    this.currencyQuery.set(q);
    this.currencyLoading.set(true);
    try {
      this.currencyOptions.set(await this.currencies.toAutocompleteOptions(q));
    } finally {
      this.currencyLoading.set(false);
    }
  }

  protected onCurrencySelect(opt: AutocompleteOption | null): void {
    this.currencyCode.set(opt?.id ?? '');
  }

  protected setDetail(key: string, value: string): void {
    this.detailValues.update((d) => ({ ...d, [key]: value }));
  }

  protected onSubmit(): void {
    this.localError.set(null);
    const method = this.effectiveMethod();
    if (!this.destinationKnown() && !method) {
      this.localError.set(this.locale.t('payments.panel.methodRequired'));
      return;
    }
    if (this.showAmount() && !this.amount().trim()) {
      this.localError.set(this.locale.t('payments.panel.amountRequired'));
      return;
    }
    const currency =
      this.fixedCurrencyCode() || this.currencyCode().trim().toUpperCase();
    if (this.showAmount() && !currency) {
      this.localError.set(this.locale.t('payments.panel.currencyRequired'));
      return;
    }

    const payload: PaymentOperationPayload = {
      operation: this.operation(),
      method,
      settlementAccountId: this.settlementAccountId() || undefined,
    };
    if (this.showAmount()) {
      payload.amount = this.amount().trim();
      payload.currencyCode = currency;
    }
    if (!this.destinationKnown() && method) {
      payload.accountIdentifier = this.accountIdentifier().trim();
      payload.accountName = this.accountName().trim();
      payload.details = { ...this.detailValues() };
    }
    this.submitted.emit(payload);
  }
}
