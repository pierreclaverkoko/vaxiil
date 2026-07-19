import { Component, computed, inject, signal } from '@angular/core';
import { Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';

import { AuthService } from '@/core/auth/auth.service';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { authUserDisplayName } from '@/models/auth-user';
import { LanguageSwitcherComponent } from '@/shared/ui/language-switcher/language-switcher';
import { SiteFooterComponent } from '@/shared/ui/site-footer/site-footer';
import { VaxiilLogoComponent } from '@/shared/ui/vaxiil-logo/vaxiil-logo';

@Component({
  selector: 'app-consumer-app-shell',
  standalone: true,
  imports: [
    RouterOutlet,
    RouterLink,
    RouterLinkActive,
    VaxiilLogoComponent,
    TranslatePipe,
    LanguageSwitcherComponent,
    SiteFooterComponent,
  ],
  templateUrl: './consumer-app-shell.html',
  styleUrl: './consumer-app-shell.scss',
})
export class ConsumerAppShellComponent {
  private readonly locale = inject(LocaleService);
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);

  protected readonly isAuthenticated = this.auth.isAuthenticated;
  protected readonly user = this.auth.currentUser;
  protected readonly isStaff = computed(() => this.user()?.isStaff === true);
  protected readonly menuOpen = signal(false);

  protected readonly displayName = computed(() => {
    const u = this.user();
    return u ? authUserDisplayName(u) : '';
  });

  protected readonly navItems = computed(() => {
    this.locale.locale();
    const items = [
      {
        path: '/discover',
        label: this.locale.t('shell.consumer.discover'),
        icon: 'explore',
        guest: true,
      },
      {
        path: '/services',
        label: this.locale.t('shell.consumer.services'),
        icon: 'spa',
        guest: true,
      },
      {
        path: '/bookings',
        label: this.locale.t('shell.consumer.bookings'),
        icon: 'event',
        guest: false,
      },
      {
        path: '/profile',
        label: this.locale.t('shell.consumer.profile'),
        icon: 'person',
        guest: false,
      },
    ];
    if (this.isAuthenticated()) {
      return items;
    }
    return items.filter((i) => i.guest);
  });

  protected toggleMenu(): void {
    this.menuOpen.update((v) => !v);
  }

  protected closeMenu(): void {
    this.menuOpen.set(false);
  }

  protected async onLogout(): Promise<void> {
    this.closeMenu();
    await this.auth.logout();
    await this.router.navigateByUrl('/discover');
  }
}
