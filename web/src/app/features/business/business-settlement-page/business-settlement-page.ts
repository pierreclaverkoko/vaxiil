import { Component, OnInit, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute } from '@angular/router';

import { ApiError } from '@/core/http/api-error';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { routeParam } from '@/core/router/route-param';
import { OrganizationsService } from '@/features/business/organizations.service';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';

@Component({
  selector: 'app-business-settlement-page',
  standalone: true,
  imports: [FormsModule, ButtonComponent, ErrorStateComponent, TranslatePipe],
  template: `
    <section class="settlement">
      <header>
        <h1>{{ 'business.settlement.title' | t }}</h1>
        <p>{{ 'business.settlement.lede' | t }}</p>
      </header>

      @if (loadError()) {
        <app-error-state [message]="loadError()!" />
      } @else {
        <h2>{{ 'business.settlement.balance' | t }}</h2>
        <ul>
          @for (b of balances(); track b.currency_code) {
            <li>
              {{ b.currency_code }}: {{ b.available }}
              ({{ 'business.settlement.ledgerBalance' | t }} {{ b.balance }})
            </li>
          } @empty {
            <li>{{ 'business.settlement.noBalance' | t }}</li>
          }
        </ul>

        <h2>{{ 'business.settlement.settings' | t }}</h2>
        @if (settings(); as s) {
          <label>
            {{ 'business.settlement.periodicity' | t }}
            <select [(ngModel)]="periodicity" (ngModelChange)="saveSettings()">
              <option value="W">{{ 'business.settlement.weekly' | t }}</option>
              <option value="B">{{ 'business.settlement.biweekly' | t }}</option>
              <option value="M">{{ 'business.settlement.monthly' | t }}</option>
              <option value="N">{{ 'business.settlement.manual' | t }}</option>
            </select>
          </label>
          <label>
            {{ 'business.settlement.minimum' | t }}
            <input type="number" step="0.01" [(ngModel)]="minimumAmount" (change)="saveSettings()" />
            {{ s.currency_code }}
          </label>
          <p class="hint">{{ 'business.settlement.minimumFloor' | t }}: {{ s.minimum_floor }}</p>
        }

        <h2>{{ 'business.settlement.accounts' | t }}</h2>
        <ul>
          @for (a of accounts(); track a.id) {
            <li>
              {{ a.method?.title || a.method?.value }} —
              {{ a.interac_email || a.iban || a.phone_number || a.label }}
            </li>
          } @empty {
            <li>{{ 'business.settlement.noAccounts' | t }}</li>
          }
        </ul>
        <div class="add-account">
          <select [(ngModel)]="newMethod">
            <option value="I">Interac</option>
            <option value="B">IBAN</option>
            <option value="M">Mobile money</option>
          </select>
          @if (newMethod === 'I') {
            <input type="email" [(ngModel)]="newEmail" [placeholder]="'business.settlement.email' | t" />
          }
          @if (newMethod === 'B') {
            <input [(ngModel)]="newHolder" [placeholder]="'business.settlement.holder' | t" />
            <input [(ngModel)]="newIban" placeholder="IBAN" />
          }
          @if (newMethod === 'M') {
            <input [(ngModel)]="newPhone" [placeholder]="'business.settlement.phone' | t" />
          }
          <app-button type="button" variant="secondary" (click)="addAccount()">{{
            'business.settlement.addAccount' | t
          }}</app-button>
        </div>

        <h2>{{ 'business.settlement.manualRequest' | t }}</h2>
        <input type="number" step="0.01" [(ngModel)]="requestAmount" />
        <select [(ngModel)]="requestAccountId">
          @for (a of accounts(); track a.id) {
            <option [value]="a.id">{{ a.interac_email || a.iban || a.phone_number || a.id }}</option>
          }
        </select>
        <app-button type="button" variant="primary" [disabled]="submitting()" (click)="requestSettlement()">{{
          'business.settlement.request' | t
        }}</app-button>
        @if (actionError()) {
          <p role="alert">{{ actionError() }}</p>
        }

        <h2>{{ 'business.settlement.history' | t }}</h2>
        <ul>
          @for (r of requests(); track r.id) {
            <li>{{ r.amount }} {{ r.currency_code }} — {{ r.status?.title || r.status?.value }}</li>
          } @empty {
            <li>{{ 'business.settlement.noRequests' | t }}</li>
          }
        </ul>
      }
    </section>
  `,
  styles: [
    `
      .settlement {
        padding: 1.5rem;
        max-width: 40rem;
      }
      h2 {
        margin-top: 1.5rem;
      }
      label,
      .add-account {
        display: flex;
        flex-direction: column;
        gap: 0.35rem;
        margin-bottom: 0.75rem;
      }
      .hint {
        font-size: 0.875rem;
        opacity: 0.8;
      }
    `,
  ],
})
export class BusinessSettlementPageComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly orgs = inject(OrganizationsService);

  protected readonly loadError = signal<string | null>(null);
  protected readonly actionError = signal<string | null>(null);
  protected readonly submitting = signal(false);
  protected readonly balances = signal<
    Array<{ currency_code: string; balance: string; available: string }>
  >([]);
  protected readonly accounts = signal<any[]>([]);
  protected readonly requests = signal<any[]>([]);
  protected readonly settings = signal<any | null>(null);

  protected periodicity = 'N';
  protected minimumAmount = '10';
  protected newMethod = 'I';
  protected newEmail = '';
  protected newHolder = '';
  protected newIban = '';
  protected newPhone = '';
  protected requestAmount = '';
  protected requestAccountId = '';

  private orgId = '';

  async ngOnInit(): Promise<void> {
    this.orgId = routeParam(this.route, 'orgId') || '';
    await this.reload();
  }

  private async reload(): Promise<void> {
    try {
      const [balance, accountsRaw, settingsRaw, requestsRaw] = await Promise.all([
        this.orgs.getSettlementBalance(this.orgId),
        this.orgs.listSettlementAccounts(this.orgId),
        this.orgs.getSettlementSettings(this.orgId),
        this.orgs.listSettlementRequests(this.orgId),
      ]);
      const accounts = accountsRaw as any[];
      const settings = settingsRaw as any;
      const requests = requestsRaw as any[];
      this.balances.set(balance.balances || []);
      this.accounts.set(accounts);
      this.requests.set(requests);
      this.settings.set(settings);
      this.periodicity = settings.periodicity?.value || settings.periodicity || 'N';
      this.minimumAmount = String(settings.minimum_amount ?? '10');
      if (accounts[0]) {
        this.requestAccountId = String(accounts[0].id);
      }
    } catch (e) {
      this.loadError.set((e as ApiError).message);
    }
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

  protected async addAccount(): Promise<void> {
    try {
      const body: Record<string, unknown> = { method: this.newMethod, is_default: true };
      if (this.newMethod === 'I') {
        body['interac_email'] = this.newEmail;
      } else if (this.newMethod === 'B') {
        body['account_holder_name'] = this.newHolder;
        body['iban'] = this.newIban;
      } else {
        body['phone_number'] = this.newPhone;
      }
      await this.orgs.createSettlementAccount(this.orgId, body);
      this.newEmail = '';
      this.newIban = '';
      this.newPhone = '';
      await this.reload();
    } catch (e) {
      this.actionError.set((e as ApiError).message);
    }
  }

  protected async requestSettlement(): Promise<void> {
    if (!this.requestAccountId || !this.requestAmount) {
      return;
    }
    this.submitting.set(true);
    this.actionError.set(null);
    try {
      await this.orgs.createSettlementRequest(this.orgId, {
        amount: this.requestAmount,
        account_id: this.requestAccountId,
      });
      this.requestAmount = '';
      await this.reload();
    } catch (e) {
      this.actionError.set((e as ApiError).message);
    } finally {
      this.submitting.set(false);
    }
  }
}
