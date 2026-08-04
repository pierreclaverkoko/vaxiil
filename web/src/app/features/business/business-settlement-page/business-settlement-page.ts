import { Component, OnInit, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute } from '@angular/router';

import { ApiError } from '@/core/http/api-error';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { routeParam } from '@/core/router/route-param';
import { OrganizationsService } from '@/features/business/organizations.service';
import {
  PaymentCatalogService,
  PaymentMethodBrief,
  PaymentOperationPayload,
} from '@/shared/payments/payment-catalog.service';
import { PaymentOperationPanelComponent } from '@/shared/payments/payment-operation-panel/payment-operation-panel';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';

@Component({
  selector: 'app-business-settlement-page',
  standalone: true,
  imports: [
    FormsModule,
    ButtonComponent,
    ErrorStateComponent,
    TranslatePipe,
    PaymentOperationPanelComponent,
  ],
  templateUrl: './business-settlement-page.html',
  styleUrl: './business-settlement-page.scss',
})
export class BusinessSettlementPageComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly orgs = inject(OrganizationsService);
  private readonly catalog = inject(PaymentCatalogService);

  protected readonly loadError = signal<string | null>(null);
  protected readonly actionError = signal<string | null>(null);
  protected readonly submitting = signal(false);
  protected readonly balances = signal<
    { currency_code: string; balance: string; available: string }[]
  >([]);
  protected readonly accounts = signal<Record<string, unknown>[]>([]);
  protected readonly requests = signal<Record<string, unknown>[]>([]);
  protected readonly settings = signal<Record<string, unknown> | null>(null);

  protected periodicity = 'N';
  protected minimumAmount = '10';
  protected requestAccountId = '';
  protected showAddAccount = false;
  protected readonly orgCountryId = signal<string | null>(null);

  private orgId = '';

  async ngOnInit(): Promise<void> {
    this.orgId = routeParam(this.route, 'orgId') || '';
    await this.reload();
  }

  protected accountLabel(a: Record<string, unknown>): string {
    const method = a['method'] as Record<string, unknown> | undefined;
    const name = typeof method?.['name'] === 'string' ? method['name'] : '';
    const id =
      typeof a['account_identifier'] === 'string' ? a['account_identifier'] : '';
    return [name, id].filter(Boolean).join(' — ') || String(a['id'] ?? '');
  }

  protected accountId(a: Record<string, unknown>): string {
    return String(a['id'] ?? '');
  }

  protected fixedRequestCurrency(): string {
    return (
      this.balances()[0]?.currency_code ||
      String(this.settings()?.['currency_code'] || '')
    );
  }

  protected selectedAccount(): Record<string, unknown> | null {
    return this.accounts().find((a) => String(a['id']) === this.requestAccountId) ?? null;
  }

  protected accountMethod(a: Record<string, unknown>): PaymentMethodBrief | null {
    const method = a['method'];
    if (!method || typeof method !== 'object') return null;
    return this.catalog.parseMethod(method as Record<string, unknown>);
  }

  protected async saveSettings(): Promise<void> {
    try {
      await this.orgs.patchSettlementSettings(this.orgId, {
        periodicity: this.periodicity,
        minimum_amount: this.minimumAmount,
      });
      await this.reload();
    } catch (e) {
      this.actionError.set((e as ApiError).message);
    }
  }

  protected async onCreateAccount(payload: PaymentOperationPayload): Promise<void> {
    if (!payload.method) return;
    this.submitting.set(true);
    this.actionError.set(null);
    try {
      await this.orgs.createSettlementAccount(this.orgId, {
        method_id: payload.method.id,
        account_identifier: payload.accountIdentifier || '',
        account_name: payload.accountName || '',
        details: payload.details || {},
        is_default: this.accounts().length === 0,
        label: payload.method.name,
      });
      this.showAddAccount = false;
      await this.reload();
    } catch (e) {
      this.actionError.set((e as ApiError).message);
    } finally {
      this.submitting.set(false);
    }
  }

  protected async onRequestSettlement(payload: PaymentOperationPayload): Promise<void> {
    if (!payload.settlementAccountId || !payload.amount) return;
    this.submitting.set(true);
    this.actionError.set(null);
    try {
      const body: Record<string, unknown> = {
        amount: payload.amount,
        account_id: payload.settlementAccountId,
      };
      if (payload.currencyCode) {
        body['currency_code'] = payload.currencyCode;
      }
      await this.orgs.createSettlementRequest(this.orgId, body);
      await this.reload();
    } catch (e) {
      this.actionError.set((e as ApiError).message);
    } finally {
      this.submitting.set(false);
    }
  }

  private async reload(): Promise<void> {
    try {
      const [balance, accountsRaw, settingsRaw, requestsRaw, org] = await Promise.all([
        this.orgs.getSettlementBalance(this.orgId),
        this.orgs.listSettlementAccounts(this.orgId),
        this.orgs.getSettlementSettings(this.orgId),
        this.orgs.listSettlementRequests(this.orgId),
        this.orgs.getById(this.orgId),
      ]);
      const accounts = accountsRaw as Record<string, unknown>[];
      const settings = settingsRaw as Record<string, unknown>;
      this.balances.set(balance.balances || []);
      this.accounts.set(accounts);
      this.requests.set(requestsRaw as Record<string, unknown>[]);
      this.settings.set(settings);
      this.orgCountryId.set(org.countryId);
      const period = settings['periodicity'];
      this.periodicity =
        period && typeof period === 'object' && 'value' in period
          ? String((period as { value: unknown }).value)
          : typeof period === 'string'
            ? period
            : 'N';
      this.minimumAmount = String(settings['minimum_amount'] ?? '10');
      if (accounts[0] && !this.requestAccountId) {
        this.requestAccountId = String(accounts[0]['id']);
      }
    } catch (e) {
      this.loadError.set((e as ApiError).message);
    }
  }
}
