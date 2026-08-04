import {
  Component,
  OnInit,
  computed,
  effect,
  inject,
  input,
  output,
  signal,
} from '@angular/core';

import { OrganizationsService } from '@/features/business/organizations.service';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { CountryBrief } from '@/models/organization';
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

type WizardStep = 1 | 2 | 3 | 4;

const CATEGORIES: { value: string; key: string; icon: string }[] = [
  { value: 'B', key: 'payments.picker.typeBank', icon: 'account_balance' },
  { value: 'M', key: 'payments.picker.typeMomo', icon: 'smartphone' },
  { value: 'F', key: 'payments.picker.typeFintech', icon: 'payments' },
  { value: 'C', key: 'payments.picker.typeCrypto', icon: 'currency_bitcoin' },
];

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
export class PaymentOperationPanelComponent implements OnInit {
  private readonly currencies = inject(CurrencySearchService);
  private readonly locale = inject(LocaleService);
  private readonly orgs = inject(OrganizationsService);

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
  /** Optional external error (e.g. API failure from parent). */
  readonly externalError = input<string | null>(null);
  readonly externalErrorTitle = input<string | null>(null);

  readonly submitted = output<PaymentOperationPayload>();

  protected readonly categories = CATEGORIES;
  protected readonly step = signal<WizardStep>(1);
  protected readonly category = signal<string | null>(null);
  protected readonly selectedMethod = signal<PaymentMethodBrief | null>(null);
  protected readonly countryFilter = signal<string>('');
  protected readonly countries = signal<CountryBrief[]>([]);
  protected readonly accountIdentifier = signal('');
  protected readonly nationalNumber = signal('');
  protected readonly dialIso = signal('');
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

  protected readonly identifierType = computed(
    () => this.effectiveMethod()?.identifierType ?? 'generic',
  );

  protected readonly accountPlaceholder = computed(() => {
    const fromApi = this.effectiveMethod()?.accountPlaceholder?.trim();
    if (fromApi) return fromApi;
    const type = this.identifierType();
    if (type === 'phone') {
      return this.locale.t('payments.panel.phonePlaceholder');
    }
    if (type === 'email') {
      return this.locale.t('payments.panel.emailPlaceholder');
    }
    return this.locale.t('payments.panel.genericPlaceholder');
  });

  protected readonly accountLabelKey = computed(() => {
    const type = this.identifierType();
    if (type === 'phone') return 'payments.panel.phoneNumber';
    if (type === 'email') return 'payments.panel.emailAddress';
    return 'payments.panel.accountIdentifier';
  });

  protected readonly dialCountries = computed(() => {
    const all = this.countries().filter((c) => !!c.phoneCode);
    const allow = this.effectiveMethod()?.phoneCountryCodes ?? [];
    if (!allow.length) return all;
    const set = new Set(allow.map((c) => c.toUpperCase()));
    return all.filter((c) => set.has(c.isoCode2.toUpperCase()));
  });

  protected readonly displayedError = computed(
    () => this.localError() || this.externalError(),
  );

  protected readonly displayedErrorTitle = computed(
    () => this.externalErrorTitle() || this.displayedError(),
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
    effect(() => {
      const incoming = this.country();
      if (incoming && !this.countryFilter()) {
        this.countryFilter.set(incoming);
      }
    });
    effect(() => {
      const method = this.effectiveMethod();
      if (method?.currencyCode) {
        this.currencyCode.set(method.currencyCode);
        this.currencyQuery.set(method.currencyCode);
      }
    });
    effect(() => {
      const method = this.effectiveMethod();
      const dials = this.dialCountries();
      if (!method || method.identifierType !== 'phone' || !dials.length) {
        return;
      }
      const current = this.dialIso();
      if (current && dials.some((c) => c.isoCode2 === current)) {
        return;
      }
      const byMethod = dials.find(
        (c) =>
          method.countryCode &&
          c.isoCode2.toUpperCase() === method.countryCode.toUpperCase(),
      );
      this.dialIso.set(byMethod?.isoCode2 ?? dials[0].isoCode2);
    });
  }

  async ngOnInit(): Promise<void> {
    if (this.country()) {
      this.countryFilter.set(this.country()!);
    }
    if (this.methodKnown()) {
      this.step.set(this.showAmount() || this.showDestination() ? 3 : 4);
    }
    try {
      this.countries.set(await this.orgs.listCountries());
    } catch {
      this.countries.set([]);
    }
  }

  protected pickCategory(value: string): void {
    this.category.set(value);
    this.selectedMethod.set(null);
    this.localError.set(null);
    this.step.set(2);
  }

  protected onMethodSelected(method: PaymentMethodBrief | null): void {
    this.selectedMethod.set(method);
    this.localError.set(null);
    this.accountIdentifier.set('');
    this.nationalNumber.set('');
    if (method) {
      this.step.set(3);
    }
  }

  protected onCountryFilterChange(event: Event): void {
    this.countryFilter.set((event.target as HTMLSelectElement).value);
    this.selectedMethod.set(null);
  }

  protected onDialChange(event: Event): void {
    this.dialIso.set((event.target as HTMLSelectElement).value);
  }

  protected goBack(): void {
    this.localError.set(null);
    const current = this.step();
    if (current === 2) {
      this.step.set(1);
      this.category.set(null);
      this.selectedMethod.set(null);
    } else if (current === 3) {
      if (this.methodKnown()) {
        return;
      }
      this.step.set(2);
    } else if (current === 4) {
      this.step.set(3);
    }
  }

  protected resolvedAccountIdentifier(): string {
    if (this.identifierType() !== 'phone') {
      return this.accountIdentifier().trim();
    }
    const national = this.nationalNumber().trim().replace(/^0+/, '');
    const country = this.dialCountries().find((c) => c.isoCode2 === this.dialIso());
    const code = (country?.phoneCode || '').replace(/^\+/, '');
    if (!national) return '';
    if (!code) return national.startsWith('+') ? national : `+${national}`;
    return `+${code}${national}`;
  }

  protected goNextFromDetails(): void {
    this.localError.set(null);
    if (this.showDestination()) {
      const id = this.resolvedAccountIdentifier();
      if (!id) {
        this.localError.set(this.locale.t('payments.panel.accountRequired'));
        return;
      }
      if (this.identifierType() === 'email' && !id.includes('@')) {
        this.localError.set(this.locale.t('payments.panel.emailInvalid'));
        return;
      }
      this.accountIdentifier.set(id);
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
    const method = this.effectiveMethod();
    if (method?.currencyCode && currency && method.currencyCode !== currency) {
      this.localError.set(
        this.locale.t('payments.panel.currencyMismatch', {
          code: method.currencyCode,
        }),
      );
      return;
    }
    this.step.set(4);
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

  protected onConfirm(): void {
    this.localError.set(null);
    const method = this.effectiveMethod();
    if (!this.destinationKnown() && !method) {
      this.localError.set(this.locale.t('payments.panel.methodRequired'));
      return;
    }
    const currency =
      this.fixedCurrencyCode() || this.currencyCode().trim().toUpperCase();
    if (method?.currencyCode && currency && method.currencyCode !== currency) {
      this.localError.set(
        this.locale.t('payments.panel.currencyMismatch', {
          code: method.currencyCode,
        }),
      );
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
      payload.accountIdentifier = this.resolvedAccountIdentifier();
      payload.accountName = this.accountName().trim();
      payload.details = { ...this.detailValues() };
    }
    this.submitted.emit(payload);
  }
}
