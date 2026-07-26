import { DatePipe } from '@angular/common';
import { Component, OnInit, inject, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';

import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { MessagingService } from '@/features/messages/messaging.service';
import { ConversationSummary, conversationInitials } from '@/models/messaging';
import { ChoiceEnumChipComponent } from '@/shared/ui/choice-enum-chip/choice-enum-chip';
import { EmptyStateComponent } from '@/shared/ui/empty-state/empty-state';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';

@Component({
  selector: 'app-staff-messages-page',
  standalone: true,
  imports: [
    RouterLink,
    TranslatePipe,
    EmptyStateComponent,
    ErrorStateComponent,
    ChoiceEnumChipComponent,
    DatePipe,
  ],
  templateUrl: './staff-messages-page.html',
  styleUrl: './staff-messages-page.scss',
})
export class StaffMessagesPageComponent implements OnInit {
  private readonly api = inject(MessagingService);
  private readonly locale = inject(LocaleService);
  private readonly router = inject(Router);

  protected readonly loading = signal(true);
  protected readonly loadError = signal<string | null>(null);
  protected readonly conversations = signal<ConversationSummary[]>([]);
  protected readonly initials = conversationInitials;

  async ngOnInit(): Promise<void> {
    await this.reload();
  }

  protected async reload(): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      const page = await this.api.listConversations({
        pageSize: 50,
        scope: 'staff',
      });
      this.conversations.set(page.results);
    } catch (e) {
      this.loadError.set(e instanceof Error ? e.message : this.locale.t('messages.loadError'));
    } finally {
      this.loading.set(false);
    }
  }

  protected openThread(id: string): void {
    void this.router.navigate(['/staff', 'messages', id]);
  }
}
