import { Location } from '@angular/common';
import {
  Component,
  HostListener,
  OnDestroy,
  OnInit,
  inject,
  signal,
} from '@angular/core';
import { RouterOutlet } from '@angular/router';

import { TranslatePipe } from '@/core/i18n/translate.pipe';

const MD_QUERY = '(min-width: 768px)';

/**
 * Route wrapper: full page below md; centered dismissible panel (max 720px) at md+.
 * Matches Flutter `vaxiilAdaptivePage` / `modalOnWide`.
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
    this.location.back();
  }

  private readonly onMediaChange = (event: MediaQueryListEvent): void => {
    this.wide.set(event.matches);
  };
}
