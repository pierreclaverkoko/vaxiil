import { Component, OnInit, inject, input, signal } from '@angular/core';
import { Router } from '@angular/router';

import { ApiError } from '@/core/http/api-error';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { NotificationsService } from '@/features/notifications/notifications.service';
import {
  AppNotification,
  isNotificationUnread,
  notificationIcon,
} from '@/models/notification';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';

@Component({
  selector: 'app-scoped-notifications-page',
  standalone: true,
  imports: [ButtonComponent, ErrorStateComponent, TranslatePipe],
  templateUrl: './scoped-notifications-page.html',
  styleUrl: './scoped-notifications-page.scss',
})
export class ScopedNotificationsPageComponent implements OnInit {
  private readonly api = inject(NotificationsService);
  private readonly router = inject(Router);

  /** When set, loads organization-scoped feed. */
  readonly organizationId = input<string | null>(null);
  /** personal | staff — used when organizationId is absent. */
  readonly scope = input<'personal' | 'staff'>('personal');

  protected readonly items = signal<AppNotification[]>([]);
  protected readonly loading = signal(true);
  protected readonly loadError = signal<string | null>(null);

  protected readonly isUnread = isNotificationUnread;
  protected readonly iconFor = notificationIcon;

  async ngOnInit(): Promise<void> {
    await this.reload();
  }

  protected async reload(): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      const orgId = this.organizationId();
      const page = await this.api.list({
        pageSize: 50,
        ...(orgId
          ? { organizationId: orgId }
          : { scope: this.scope() }),
      });
      this.items.set(page.results);
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    } finally {
      this.loading.set(false);
    }
  }

  protected async markAllRead(): Promise<void> {
    const orgId = this.organizationId();
    await this.api.markAllRead(
      orgId ? { organizationId: orgId } : { scope: this.scope() },
    );
    await this.reload();
  }

  protected async onOpen(n: AppNotification): Promise<void> {
    if (isNotificationUnread(n)) {
      try {
        await this.api.markRead(n.id);
      } catch {
        // still navigate
      }
    }
    const orgId = this.organizationId();
    if (n.conversationId) {
      if (orgId) {
        await this.router.navigate(['/business', orgId, 'messages', n.conversationId]);
      } else if (this.scope() === 'staff') {
        await this.router.navigate(['/staff', 'messages', n.conversationId]);
      } else {
        await this.router.navigate(['/messages', n.conversationId]);
      }
      return;
    }
    if (n.bookingId && orgId) {
      await this.router.navigate(['/business', orgId, 'bookings', n.bookingId]);
      return;
    }
    if (n.bookingId) {
      await this.router.navigate(['/bookings', n.bookingId]);
    }
  }

  protected titleKey(): string {
    return this.organizationId()
      ? 'notifications.businessTitle'
      : this.scope() === 'staff'
        ? 'notifications.staffTitle'
        : 'notifications.title';
  }
}
