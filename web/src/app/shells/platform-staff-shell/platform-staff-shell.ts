import { Component, computed, inject } from '@angular/core';
import { Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';

import { AuthService } from '@/core/auth/auth.service';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { VaxiilLogoComponent } from '@/shared/ui/vaxiil-logo/vaxiil-logo';
import { environment } from '../../../environments/environment';

@Component({
  selector: 'app-platform-staff-shell',
  standalone: true,
  imports: [
    RouterOutlet,
    RouterLink,
    RouterLinkActive,
    VaxiilLogoComponent,
    TranslatePipe,
  ],
  templateUrl: './platform-staff-shell.html',
  styleUrl: './platform-staff-shell.scss',
})
export class PlatformStaffShellComponent {
  private readonly locale = inject(LocaleService);
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);

  protected async onLogout(): Promise<void> {
    await this.auth.logout();
    await this.router.navigateByUrl('/discover');
  }

  protected readonly navItems = computed(() => {
    this.locale.locale();
    return [
      {
        path: '/staff',
        label: this.locale.t('shell.staff.overview'),
        icon: 'admin_panel_settings',
        exact: true,
      },
      {
        path: '/staff/users',
        label: this.locale.t('shell.staff.users'),
        icon: 'badge',
        exact: false,
      },
      {
        path: '/staff/organizations',
        label: this.locale.t('shell.staff.organizations'),
        icon: 'domain',
        exact: false,
      },
      {
        path: '/staff/taxonomy',
        label: this.locale.t('shell.staff.taxonomy'),
        icon: 'category',
        exact: false,
      },
      {
        path: '/staff/bookings',
        label: this.locale.t('shell.staff.bookings'),
        icon: 'event_note',
        exact: false,
      },
      {
        path: '/staff/payments',
        label: this.locale.t('shell.staff.payments'),
        icon: 'payments',
        exact: false,
      },
      {
        path: '/staff/fees',
        label: this.locale.t('shell.staff.fees'),
        icon: 'account_balance',
        exact: false,
      },
      ...(environment.featureFlags.messagesEnabled
        ? [
            {
              path: '/staff/messages',
              label: this.locale.t('shell.staff.messages'),
              icon: 'forum',
              exact: false,
            },
          ]
        : []),
      {
        path: '/staff/notifications',
        label: this.locale.t('shell.staff.notifications'),
        icon: 'notifications',
        exact: false,
      },
    ];
  });
}
