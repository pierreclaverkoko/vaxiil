import {
  AfterViewInit,
  Component,
  ElementRef,
  OnDestroy,
  input,
  output,
  signal,
  viewChild,
} from '@angular/core';

import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { environment } from '../../../../environments/environment';

declare global {
  interface Window {
    turnstile?: {
      render: (
        el: HTMLElement,
        options: {
          sitekey: string;
          action?: string;
          callback?: (token: string) => void;
          'expired-callback'?: () => void;
          'error-callback'?: () => void;
        },
      ) => string;
      reset: (widgetId?: string) => void;
      remove: (widgetId?: string) => void;
    };
    onTurnstileApiLoad?: () => void;
  }
}

const SCRIPT_ID = 'cf-turnstile-api';
const SCRIPT_SRC =
  'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit&onload=onTurnstileApiLoad';

let scriptLoadPromise: Promise<void> | null = null;

function loadTurnstileScript(): Promise<void> {
  if (typeof window === 'undefined') {
    return Promise.reject(new Error('Turnstile requires a browser'));
  }
  if (window.turnstile) {
    return Promise.resolve();
  }
  if (scriptLoadPromise) {
    return scriptLoadPromise;
  }
  scriptLoadPromise = new Promise<void>((resolve, reject) => {
    const existing = document.getElementById(SCRIPT_ID);
    if (existing && window.turnstile) {
      resolve();
      return;
    }
    const previous = window.onTurnstileApiLoad;
    window.onTurnstileApiLoad = () => {
      previous?.();
      resolve();
    };
    if (!existing) {
      const script = document.createElement('script');
      script.id = SCRIPT_ID;
      script.src = SCRIPT_SRC;
      script.async = true;
      script.defer = true;
      script.onerror = () => {
        scriptLoadPromise = null;
        reject(new Error('Failed to load Turnstile'));
      };
      document.head.appendChild(script);
    }
  });
  return scriptLoadPromise;
}

@Component({
  selector: 'app-turnstile',
  standalone: true,
  imports: [TranslatePipe],
  templateUrl: './turnstile.html',
  styleUrl: './turnstile.scss',
})
export class TurnstileComponent implements AfterViewInit, OnDestroy {
  /** Optional override; defaults to environment.turnstileSiteKey. */
  readonly siteKey = input<string>(environment.turnstileSiteKey);
  readonly tokenChange = output<string | null>();

  protected readonly token = signal<string | null>(null);
  protected readonly loadError = signal(false);

  private readonly container = viewChild<ElementRef<HTMLDivElement>>('widget');
  private widgetId: string | null = null;
  private destroyed = false;

  async ngAfterViewInit(): Promise<void> {
    try {
      await loadTurnstileScript();
      if (this.destroyed) {
        return;
      }
      this.renderWidget();
    } catch {
      this.loadError.set(true);
      this.token.set(null);
      this.tokenChange.emit(null);
    }
  }

  ngOnDestroy(): void {
    this.destroyed = true;
    if (this.widgetId != null && window.turnstile) {
      try {
        window.turnstile.remove(this.widgetId);
      } catch {
        // ignore
      }
    }
  }

  /** Clear token and re-render challenge (e.g. after step change). */
  reset(): void {
    this.token.set(null);
    this.tokenChange.emit(null);
    if (this.widgetId != null && window.turnstile) {
      window.turnstile.reset(this.widgetId);
    }
  }

  private renderWidget(): void {
    const el = this.container()?.nativeElement;
    if (!el || !window.turnstile) {
      return;
    }
    this.widgetId = window.turnstile.render(el, {
      sitekey: this.siteKey(),
      action: 'turnstile-spin-v2',
      callback: (value: string) => {
        this.token.set(value);
        this.tokenChange.emit(value);
      },
      'expired-callback': () => {
        this.token.set(null);
        this.tokenChange.emit(null);
      },
      'error-callback': () => {
        this.token.set(null);
        this.tokenChange.emit(null);
      },
    });
  }
}
