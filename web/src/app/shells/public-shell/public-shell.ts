import { Component, computed, inject } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { NavigationEnd, Router, RouterLink, RouterOutlet } from '@angular/router';
import { filter, map, startWith } from 'rxjs';

import { StitchImages } from '@/core/constants/stitch-images';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { LanguageSwitcherComponent } from '@/shared/ui/language-switcher/language-switcher';
import { VaxiilLogoComponent } from '@/shared/ui/vaxiil-logo/vaxiil-logo';

@Component({
  selector: 'app-public-shell',
  standalone: true,
  imports: [
    RouterOutlet,
    RouterLink,
    VaxiilLogoComponent,
    TranslatePipe,
    LanguageSwitcherComponent,
  ],
  templateUrl: './public-shell.html',
  styleUrl: './public-shell.scss',
})
export class PublicShellComponent {
  private readonly router = inject(Router);
  private readonly locale = inject(LocaleService);

  private readonly url = toSignal(
    this.router.events.pipe(
      filter((e): e is NavigationEnd => e instanceof NavigationEnd),
      map(() => this.router.url),
      startWith(this.router.url),
    ),
    { initialValue: this.router.url },
  );

  protected readonly panelImage = computed(() => {
    const path = this.url().split('?')[0] ?? '';
    if (path.startsWith('/register')) {
      return StitchImages.signupSidePanel;
    }
    if (path.startsWith('/onboarding') || path === '/') {
      return StitchImages.splashCollage1;
    }
    return StitchImages.loginSidePanel;
  });

  protected readonly panelAlt = computed(() => {
    this.locale.locale();
    const path = this.url().split('?')[0] ?? '';
    if (path.startsWith('/register')) {
      return this.locale.t('shell.public.panelAltRegister');
    }
    if (path.startsWith('/onboarding') || path === '/') {
      return this.locale.t('shell.public.panelAltOnboarding');
    }
    return this.locale.t('shell.public.panelAltDefault');
  });

  protected readonly panelHeadline = computed(() => {
    this.locale.locale();
    const path = this.url().split('?')[0] ?? '';
    if (path.startsWith('/register')) {
      return this.locale.t('shell.public.panelHeadlineRegister');
    }
    if (path.startsWith('/onboarding') || path === '/') {
      return this.locale.t('shell.public.panelHeadlineOnboarding');
    }
    return this.locale.t('shell.public.panelHeadlineDefault');
  });

  protected readonly panelLede = computed(() => {
    this.locale.locale();
    const path = this.url().split('?')[0] ?? '';
    if (path.startsWith('/register')) {
      return this.locale.t('shell.public.panelLedeRegister');
    }
    if (path.startsWith('/onboarding') || path === '/') {
      return this.locale.t('shell.public.panelLedeOnboarding');
    }
    return this.locale.t('shell.public.panelLedeDefault');
  });
}
