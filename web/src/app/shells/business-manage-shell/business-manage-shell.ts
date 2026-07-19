import { Component, OnInit, computed, inject } from '@angular/core';
import {
  ActivatedRoute,
  NavigationEnd,
  Router,
  RouterLink,
  RouterLinkActive,
  RouterOutlet,
} from '@angular/router';
import { filter } from 'rxjs/operators';

import { AuthService } from '@/core/auth/auth.service';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { OrganizationContextService } from '@/features/business/organization-context.service';
import { VaxiilLogoComponent } from '@/shared/ui/vaxiil-logo/vaxiil-logo';

@Component({
  selector: 'app-business-manage-shell',
  standalone: true,
  imports: [
    RouterOutlet,
    RouterLink,
    RouterLinkActive,
    VaxiilLogoComponent,
    TranslatePipe,
  ],
  templateUrl: './business-manage-shell.html',
  styleUrl: './business-manage-shell.scss',
})
export class BusinessManageShellComponent implements OnInit {
  private readonly locale = inject(LocaleService);
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  private readonly route = inject(ActivatedRoute);
  private readonly orgCtx = inject(OrganizationContextService);

  protected readonly orgs = this.orgCtx.organizations;
  protected readonly currentOrg = this.orgCtx.currentOrg;
  protected readonly currentOrgId = this.orgCtx.currentOrgId;
  protected readonly isStaff = computed(() => this.auth.currentUser()?.isStaff === true);

  protected readonly navItems = computed(() => {
    this.locale.locale();
    const orgId = this.currentOrgId();
    if (!orgId) {
      return [
        {
          path: '/business',
          label: this.locale.t('shell.business.companies'),
          icon: 'storefront',
          exact: true,
        },
      ];
    }
    const base = `/business/${orgId}`;
    return [
      {
        path: base,
        label: this.locale.t('shell.business.hub'),
        icon: 'dashboard',
        exact: true,
      },
      {
        path: `${base}/services`,
        label: this.locale.t('shell.business.services'),
        icon: 'spa',
        exact: false,
      },
      {
        path: `${base}/bookings`,
        label: this.locale.t('shell.business.bookings'),
        icon: 'event_available',
        exact: false,
      },
      {
        path: `${base}/team`,
        label: this.locale.t('shell.business.team'),
        icon: 'group',
        exact: false,
      },
      {
        path: `${base}/analytics`,
        label: this.locale.t('shell.business.analytics'),
        icon: 'auto_graph',
        exact: false,
      },
      {
        path: `${base}/settings`,
        label: this.locale.t('shell.business.settings'),
        icon: 'settings',
        exact: false,
      },
    ];
  });

  async ngOnInit(): Promise<void> {
    try {
      await this.orgCtx.refresh();
    } catch {
      // error surfaced via context
    }
    this.syncOrgFromUrl();
    this.router.events
      .pipe(filter((e) => e instanceof NavigationEnd))
      .subscribe(() => this.syncOrgFromUrl());
  }

  protected onOrgChange(event: Event): void {
    const id = (event.target as HTMLSelectElement).value;
    if (!id) {
      void this.router.navigateByUrl('/business');
      return;
    }
    this.orgCtx.setCurrentOrgId(id);
    void this.router.navigate(['/business', id]);
  }

  protected async onLogout(): Promise<void> {
    await this.auth.logout();
    await this.router.navigateByUrl('/discover');
  }

  private syncOrgFromUrl(): void {
    let r: ActivatedRoute | null = this.route;
    while (r) {
      const id = r.snapshot.paramMap.get('orgId');
      if (id) {
        this.orgCtx.setCurrentOrgId(id);
        return;
      }
      r = r.firstChild;
    }
  }
}
