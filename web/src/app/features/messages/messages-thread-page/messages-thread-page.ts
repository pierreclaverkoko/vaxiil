import { DatePipe } from '@angular/common';
import { Component, OnDestroy, OnInit, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';

import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { MessagingService } from '@/features/messages/messaging.service';
import { ConversationMessage, ConversationSummary } from '@/models/messaging';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ChoiceEnumChipComponent } from '@/shared/ui/choice-enum-chip/choice-enum-chip';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';
import { ModalDialogComponent } from '@/shared/ui/modal-dialog/modal-dialog';

@Component({
  selector: 'app-messages-thread-page',
  standalone: true,
  imports: [
    RouterLink,
    FormsModule,
    TranslatePipe,
    ButtonComponent,
    ChoiceEnumChipComponent,
    ErrorStateComponent,
    ModalDialogComponent,
    DatePipe,
  ],
  templateUrl: './messages-thread-page.html',
  styleUrl: './messages-thread-page.scss',
})
export class MessagesThreadPageComponent implements OnInit, OnDestroy {
  private readonly api = inject(MessagingService);
  private readonly locale = inject(LocaleService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);

  private pollTimer: ReturnType<typeof setInterval> | null = null;

  protected readonly loading = signal(true);
  protected readonly sending = signal(false);
  protected readonly loadError = signal<string | null>(null);
  protected readonly conversation = signal<ConversationSummary | null>(null);
  protected readonly messages = signal<ConversationMessage[]>([]);
  protected readonly menuOpen = signal(false);
  protected readonly peerModalOpen = signal(false);
  protected readonly draft = signal('');
  protected readonly orgId = signal<string | null>(null);

  protected readonly inboxLink = computed(() => {
    const orgId = this.orgId();
    return orgId ? `/business/${orgId}/messages` : '/messages';
  });

  protected readonly isBookingThread = computed(() => {
    const c = this.conversation();
    return !!c?.bookingId && c.kind?.value === 'booking';
  });

  async ngOnInit(): Promise<void> {
    const id = this.route.snapshot.paramMap.get('id');
    const orgId = this.route.snapshot.paramMap.get('orgId');
    this.orgId.set(orgId);
    if (!id) {
      await this.router.navigateByUrl(this.inboxLink());
      return;
    }
    await this.load(id);
    this.pollTimer = setInterval(() => void this.poll(id), 8000);
  }

  ngOnDestroy(): void {
    if (this.pollTimer) {
      clearInterval(this.pollTimer);
    }
  }

  protected isMine(msg: ConversationMessage): boolean {
    return msg.isMine;
  }

  protected openPeerModal(): void {
    this.peerModalOpen.set(true);
  }

  protected closePeerModal(): void {
    this.peerModalOpen.set(false);
  }

  /** Booking threads open booking detail; other kinds show peer privacy modal. */
  protected onTitleClick(): void {
    if (this.isBookingThread()) {
      void this.openBookingDetail();
      return;
    }
    this.openPeerModal();
  }

  protected async openBookingDetail(): Promise<void> {
    const c = this.conversation();
    if (!c?.bookingId) {
      return;
    }
    const returnTo = this.router.url;
    const orgId = this.orgId();
    // Business shell → staff booking detail; consumer shell → client booking detail.
    if (orgId) {
      await this.router.navigate(['/business', orgId, 'bookings', c.bookingId], {
        state: { returnTo },
      });
      return;
    }
    await this.router.navigate(['/bookings', c.bookingId], {
      state: { returnTo },
    });
  }

  protected async load(id: string): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      const [conv, msgs] = await Promise.all([
        this.api.getConversation(id),
        this.api.listMessages(id),
      ]);
      this.conversation.set(conv);
      this.messages.set(msgs);
      await this.api.markRead(id);
    } catch (e) {
      this.loadError.set(e instanceof Error ? e.message : this.locale.t('messages.loadError'));
    } finally {
      this.loading.set(false);
    }
  }

  private async poll(id: string): Promise<void> {
    try {
      const msgs = this.messages();
      const last = msgs[msgs.length - 1];
      const since = last?.createdAt?.toISOString();
      const newer = await this.api.listMessages(id, since ? { since } : {});
      if (newer.length) {
        const known = new Set(msgs.map((m) => m.id));
        const merged = [...msgs, ...newer.filter((m) => !known.has(m.id))];
        this.messages.set(merged);
        await this.api.markRead(id);
      }
    } catch {
      /* ignore poll errors */
    }
  }

  protected async send(): Promise<void> {
    const conv = this.conversation();
    const body = this.draft().trim();
    if (!conv || !body || conv.isBlocked) {
      return;
    }
    this.sending.set(true);
    try {
      const msg = await this.api.sendMessage(conv.id, body);
      this.messages.update((list) => [...list, msg]);
      this.draft.set('');
    } catch (e) {
      this.loadError.set(e instanceof Error ? e.message : this.locale.t('messages.loadError'));
    } finally {
      this.sending.set(false);
    }
  }

  protected toggleMenu(): void {
    this.menuOpen.update((v) => !v);
  }

  protected async toggleBlock(): Promise<void> {
    const conv = this.conversation();
    if (!conv) {
      return;
    }
    this.menuOpen.set(false);
    try {
      const updated = conv.isBlocked
        ? await this.api.unblock(conv.id)
        : await this.api.block(conv.id);
      this.conversation.set(updated);
    } catch (e) {
      this.loadError.set(e instanceof Error ? e.message : this.locale.t('messages.loadError'));
    }
  }
}
