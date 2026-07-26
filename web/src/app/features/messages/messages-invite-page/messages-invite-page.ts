import { Component, OnInit, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';

import { AuthService } from '@/core/auth/auth.service';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { MessagingService } from '@/features/messages/messaging.service';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';

@Component({
  selector: 'app-messages-invite-page',
  standalone: true,
  imports: [RouterLink, FormsModule, TranslatePipe, ButtonComponent, ErrorStateComponent],
  templateUrl: './messages-invite-page.html',
  styleUrl: './messages-invite-page.scss',
})
export class MessagesInvitePageComponent implements OnInit {
  private readonly api = inject(MessagingService);
  private readonly auth = inject(AuthService);
  private readonly locale = inject(LocaleService);
  private readonly router = inject(Router);

  protected readonly target = signal('');
  protected readonly submitting = signal(false);
  protected readonly regenerating = signal(false);
  protected readonly error = signal<string | null>(null);
  protected readonly ack = signal<string | null>(null);
  protected readonly trustAlias = signal<string | null>(null);

  ngOnInit(): void {
    this.trustAlias.set(this.auth.currentUser()?.trustAlias ?? null);
    void this.auth.ensureTrustAlias().then((alias) => {
      if (alias) {
        this.trustAlias.set(alias);
      }
    });
  }

  protected async submit(): Promise<void> {
    const raw = this.target().trim();
    if (!raw) {
      return;
    }
    this.submitting.set(true);
    this.error.set(null);
    this.ack.set(null);
    try {
      const payload: { email?: string; phone?: string; trustAlias?: string } = {};
      if (raw.includes('@')) {
        payload.email = raw;
      } else if (/^\+?[\d\s()-]{6,}$/.test(raw)) {
        payload.phone = raw.replace(/\s/g, '');
      } else {
        payload.trustAlias = raw;
      }
      const detail = await this.api.submitInvite(payload);
      this.ack.set(detail);
      this.target.set('');
    } catch (e) {
      this.error.set(e instanceof Error ? e.message : this.locale.t('messages.loadError'));
    } finally {
      this.submitting.set(false);
    }
  }

  protected async regenerate(): Promise<void> {
    this.regenerating.set(true);
    this.error.set(null);
    try {
      const alias = await this.auth.regenerateTrustAlias();
      this.trustAlias.set(alias);
    } catch (e) {
      this.error.set(e instanceof Error ? e.message : this.locale.t('messages.loadError'));
    } finally {
      this.regenerating.set(false);
    }
  }

  protected done(): void {
    void this.router.navigateByUrl('/messages');
  }
}
