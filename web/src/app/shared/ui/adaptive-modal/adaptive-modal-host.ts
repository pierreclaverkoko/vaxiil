import { Location } from '@angular/common';
import {
  Component,
  HostListener,
  OnDestroy,
  OnInit,
  inject,
  signal,
} from '@angular/core';
import { ActivatedRoute, Router, RouterOutlet } from '@angular/router';

import { TranslatePipe } from '@/core/i18n/translate.pipe';

const MD_QUERY = '(min-width: 768px)';

/**
 * Route wrapper: full page below md; centered dismissible panel (max 720px) at md+.
 * Matches Flutter `vaxiilAdaptivePage` / `modalOnWide`.
 *
 * Optional route `data.dismissUrl` replaces history.back() so completed flow
 * steps do not reopen obsolete checkout/schedule modals.
 */
@Component({
  selector: 'app-adaptive-modal-host',
  standalone: true,
  imports: [RouterOutlet, TranslatePipe],
  templateUrl: './adaptive-modal-host.html',
  styleUrl: './adaptive-modal-host.scss',
})
export class AdaptiveModalHostComponent implements OnInit, OnDestroy {
  private readonly location = inject(Location);
  private readonly router = inject(Router);
  private readonly route = inject(ActivatedRoute);
  private media: MediaQueryList | null = null;

  protected readonly wide = signal(false);

  ngOnInit(): void {
    if (typeof window === 'undefined' || !window.matchMedia) {
      return;
    }
    this.media = window.matchMedia(MD_QUERY);
    this.wide.set(this.media.matches);
    this.media.addEventListener('change', this.onMediaChange);
  }

  ngOnDestroy(): void {
    this.media?.removeEventListener('change', this.onMediaChange);
  }

  @HostListener('document:keydown.escape')
  onEscape(): void {
    if (this.wide()) {
      this.dismiss();
    }
  }

  protected dismiss(): void {
    const dismissUrl = this.resolveDismissUrl();
    if (dismissUrl) {
      void this.router.navigateByUrl(dismissUrl, { replaceUrl: true });
      return;
    }
    this.location.back();
  }

  private resolveDismissUrl(): string | null {
    let current: ActivatedRoute | null = this.route;
    while (current) {
      const raw = current.snapshot.data['dismissUrl'];
      if (typeof raw === 'string' && raw.trim()) {
        return this.interpolateDismissUrl(raw.trim());
      }
      current = current.parent;
    }
    // Also check the first child (page component route data).
    const childRaw = this.route.firstChild?.snapshot.data['dismissUrl'];
    if (typeof childRaw === 'string' && childRaw.trim()) {
      return this.interpolateDismissUrl(childRaw.trim());
    }
    return null;
  }

  private interpolateDismissUrl(template: string): string {
    return template.replace(/:([A-Za-z0-9_]+)/g, (_match, key: string) => {
      let current: ActivatedRoute | null = this.route;
      while (current) {
        const value = current.snapshot.paramMap.get(key);
        if (value) {
          return value;
        }
        current = current.parent;
      }
      const childValue = this.route.firstChild?.snapshot.paramMap.get(key);
      return childValue ?? '';
    });
  }

  private readonly onMediaChange = (event: MediaQueryListEvent): void => {
    this.wide.set(event.matches);
  };
}
