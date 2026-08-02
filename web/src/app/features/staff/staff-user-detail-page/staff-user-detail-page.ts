import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';

import { ApiError } from '@/core/http/api-error';
import { routeParam } from '@/core/router/route-param';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { MessagingService } from '@/features/messages/messaging.service';
import { staffUserActions } from '@/features/staff/staff-actions';
import {
  StaffApiService,
  StaffUserRow,
  StaffWalletBalance,
} from '@/features/staff/staff-api.service';
import { CurrencySearchService } from '@/shared/payments/currency-search.service';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ChoiceEnumChipComponent } from '@/shared/ui/choice-enum-chip/choice-enum-chip';
import { DocumentPreviewComponent } from '@/shared/ui/document-preview/document-preview';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';
import {
  AutocompleteFieldComponent,
  AutocompleteOption,
} from '@/shared/ui/autocomplete-field/autocomplete-field';
import { InputComponent } from '@/shared/ui/input/input';

@Component({
  selector: 'app-staff-user-detail-page',
  standalone: true,
  imports: [
    AutocompleteFieldComponent,
    ButtonComponent,
    ChoiceEnumChipComponent,
    DocumentPreviewComponent,
    ErrorStateComponent,
    InputComponent,
    RouterLink,
    TranslatePipe,
  ],
  templateUrl: './staff-user-detail-page.html',
  styleUrl: './staff-user-detail-page.scss',
})
export class StaffUserDetailPageComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly api = inject(StaffApiService);
  private readonly messaging = inject(MessagingService);
  private readonly locale = inject(LocaleService);
  private readonly currencies = inject(CurrencySearchService);

  protected readonly user = signal<StaffUserRow | null>(null);
  protected readonly wallets = signal<StaffWalletBalance[]>([]);
  protected readonly loading = signal(true);
  protected readonly busy = signal(false);
  protected readonly loadError = signal<string | null>(null);
  protected readonly actionError = signal<string | null>(null);
  protected readonly actionSuccess = signal<string | null>(null);
  protected readonly rejectReason = signal('');
  protected readonly creditAmount = signal('');
  protected readonly creditCurrency = signal('USD');
  protected readonly creditCurrencyOptions = signal<AutocompleteOption[]>([]);
  protected readonly creditCurrencyQuery = signal('USD');
  protected readonly creditCurrencyLoading = signal(false);
  protected readonly creditNote = signal('');
  protected readonly debitAmount = signal('');
  protected readonly debitNote = signal('');
  protected readonly previewUrl = signal<string | null>(null);
  protected readonly previewTitle = signal('');
  protected readonly previewOpen = signal(false);

  protected readonly actions = computed(() =>
    staffUserActions(this.user()?.verificationStatus?.value),
  );

  protected readonly displayName = computed(() => {
    const row = this.user();
    if (!row) {
      return '';
    }
    const name = `${row.firstName} ${row.lastName}`.trim();
    return name || row.email;
  });

  async ngOnInit(): Promise<void> {
    const id = routeParam(this.route, 'userId');
    if (!id) {
      this.loadError.set(this.locale.t('staff.users.missingId'));
      this.loading.set(false);
      return;
    }
    await this.load(id);
  }

  protected openDoc(url: string | null, titleKey: string): void {
    if (!url) {
      return;
    }
    this.previewUrl.set(url);
    this.previewTitle.set(this.locale.t(titleKey));
    this.previewOpen.set(true);
  }

  protected closePreview(): void {
    this.previewOpen.set(false);
  }

  protected async onApprove(): Promise<void> {
    const row = this.user();
    if (!row || this.busy()) {
      return;
    }
    this.busy.set(true);
    this.actionError.set(null);
    try {
      this.user.set(await this.api.approveUser(row.id));
      this.actionSuccess.set(this.locale.t('staff.users.approved'));
    } catch (error) {
      this.actionError.set((error as ApiError).message);
    } finally {
      this.busy.set(false);
    }
  }

  protected async onReject(): Promise<void> {
    const row = this.user();
    if (!row || this.busy()) {
      return;
    }
    this.busy.set(true);
    this.actionError.set(null);
    try {
      this.user.set(await this.api.rejectUser(row.id, this.rejectReason()));
      this.actionSuccess.set(this.locale.t('staff.users.rejected'));
    } catch (error) {
      this.actionError.set((error as ApiError).message);
    } finally {
      this.busy.set(false);
    }
  }

  protected async onMessage(): Promise<void> {
    const row = this.user();
    if (!row || this.busy()) {
      return;
    }
    this.busy.set(true);
    this.actionError.set(null);
    try {
      const conversation = await this.messaging.openPlatformSupport(row.id);
      await this.router.navigate(['/messages', conversation.id]);
    } catch (error) {
      this.actionError.set((error as ApiError).message);
    } finally {
      this.busy.set(false);
    }
  }

  protected async onCreditCurrencyQuery(q: string): Promise<void> {
    this.creditCurrencyQuery.set(q);
    this.creditCurrencyLoading.set(true);
    try {
      this.creditCurrencyOptions.set(await this.currencies.toAutocompleteOptions(q));
    } finally {
      this.creditCurrencyLoading.set(false);
    }
  }

  protected onCreditCurrencyPick(opt: AutocompleteOption | null): void {
    this.creditCurrency.set(opt?.id ?? '');
  }

  protected async onCreditWallet(): Promise<void> {
    const row = this.user();
    if (!row || this.busy()) {
      return;
    }
    const amount = this.creditAmount().trim();
    const currency = this.creditCurrency().trim().toUpperCase();
    if (!amount || !currency) {
      this.actionError.set(this.locale.t('staff.users.walletRequired'));
      return;
    }
    this.busy.set(true);
    this.actionError.set(null);
    try {
      await this.api.creditUserWallet(row.id, {
        amount,
        currency_code: currency,
        note: this.creditNote().trim() || undefined,
      });
      this.wallets.set(await this.api.getUserWallet(row.id));
      this.creditAmount.set('');
      this.creditNote.set('');
      this.actionSuccess.set(this.locale.t('staff.users.walletCredited'));
    } catch (error) {
      this.actionError.set((error as ApiError).message);
    } finally {
      this.busy.set(false);
    }
  }

  protected async onDebitWallet(): Promise<void> {
    const row = this.user();
    if (!row || this.busy()) {
      return;
    }
    const amount = this.debitAmount().trim();
    const currency = this.creditCurrency().trim().toUpperCase();
    const note = this.debitNote().trim();
    if (!amount || !currency) {
      this.actionError.set(this.locale.t('staff.users.walletRequired'));
      return;
    }
    if (!note) {
      this.actionError.set(this.locale.t('staff.users.debitNoteRequired'));
      return;
    }
    this.busy.set(true);
    this.actionError.set(null);
    try {
      await this.api.debitUserWallet(row.id, {
        amount,
        currency_code: currency,
        note,
      });
      this.wallets.set(await this.api.getUserWallet(row.id));
      this.debitAmount.set('');
      this.debitNote.set('');
      this.actionSuccess.set(this.locale.t('staff.users.walletDebited'));
    } catch (error) {
      this.actionError.set((error as ApiError).message);
    } finally {
      this.busy.set(false);
    }
  }

  private async load(id: string): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      const [user, wallets] = await Promise.all([
        this.api.getUser(id),
        this.api.getUserWallet(id),
      ]);
      this.user.set(user);
      this.wallets.set(wallets);
      if (wallets[0]?.currencyCode) {
        this.creditCurrency.set(wallets[0].currencyCode);
      }
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    } finally {
      this.loading.set(false);
    }
  }
}
