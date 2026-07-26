import { DatePipe } from '@angular/common';
import { Component, OnInit, inject, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';

import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { MessagingService } from '@/features/messages/messaging.service';
import {
  ConversationInvite,
  ConversationSummary,
  conversationInitials,
} from '@/models/messaging';
import { ButtonComponent } from '@/shared/ui/button/button';
import { EmptyStateComponent } from '@/shared/ui/empty-state/empty-state';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';
import { ChoiceEnumChipComponent } from '@/shared/ui/choice-enum-chip/choice-enum-chip';

@Component({
  selector: 'app-messages-inbox-page',
  standalone: true,
  imports: [
    RouterLink,
    TranslatePipe,
    ButtonComponent,
    EmptyStateComponent,
    ErrorStateComponent,
    ChoiceEnumChipComponent,
    DatePipe,
  ],
  templateUrl: './messages-inbox-page.html',
  styleUrl: './messages-inbox-page.scss',
})
export class MessagesInboxPageComponent implements OnInit {
  private readonly api = inject(MessagingService);
  private readonly locale = inject(LocaleService);
  private readonly router = inject(Router);

  protected readonly tab = signal<'conversations' | 'invitations'>('conversations');
  protected readonly loading = signal(true);
  protected readonly acting = signal(false);
  protected readonly loadError = signal<string | null>(null);
  protected readonly conversations = signal<ConversationSummary[]>([]);
  protected readonly invites = signal<ConversationInvite[]>([]);

  protected readonly initials = conversationInitials;

  async ngOnInit(): Promise<void> {
    await this.reload();
  }

  protected setTab(tab: 'conversations' | 'invitations'): void {
    this.tab.set(tab);
  }

  protected async reload(): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      const [conv, inv] = await Promise.all([
        this.api.listConversations({ pageSize: 50 }),
        this.api.listIncomingInvites(),
      ]);
      this.conversations.set(conv.results);
      this.invites.set(inv);
    } catch (e) {
      this.loadError.set(e instanceof Error ? e.message : this.locale.t('messages.loadError'));
    } finally {
      this.loading.set(false);
    }
  }

  protected async accept(invite: ConversationInvite): Promise<void> {
    this.acting.set(true);
    try {
      const conv = await this.api.acceptInvite(invite.id);
      await this.router.navigateByUrl(`/messages/${conv.id}`);
    } catch (e) {
      this.loadError.set(e instanceof Error ? e.message : this.locale.t('messages.loadError'));
    } finally {
      this.acting.set(false);
    }
  }

  protected async decline(invite: ConversationInvite): Promise<void> {
    this.acting.set(true);
    try {
      await this.api.declineInvite(invite.id);
      this.invites.update((list) => list.filter((i) => i.id !== invite.id));
    } catch (e) {
      this.loadError.set(e instanceof Error ? e.message : this.locale.t('messages.loadError'));
    } finally {
      this.acting.set(false);
    }
  }
}
