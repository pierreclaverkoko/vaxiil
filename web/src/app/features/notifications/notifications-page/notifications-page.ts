import { DatePipe } from '@angular/common';
import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';

import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { BookingsService } from '@/features/bookings/bookings.service';
import { NotificationsService } from '@/features/notifications/notifications.service';
import {
  AppNotification,
  isNotificationUnread,
  isOrgFacingNotificationKind,
  notificationIcon,
} from '@/models/notification';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';

interface NotificationGroup {
  key: string;
  labelKey: string;
  items: AppNotification[];
}

@Component({
  selector: 'app-notifications-page',
  standalone: true,
  imports: [RouterLink, TranslatePipe, ButtonComponent, ErrorStateComponent, DatePipe],
  templateUrl: './notifications-page.html',
  styleUrl: './notifications-page.scss',
})
export class NotificationsPageComponent implements OnInit {
  private readonly notificationsApi = inject(NotificationsService);
  private readonly bookings = inject(BookingsService);
  private readonly router = inject(Router);
  private readonly locale = inject(LocaleService);

  protected readonly loading = signal(true);
  protected readonly acting = signal(false);
  protected readonly loadError = signal<string | null>(null);
  protected readonly items = signal<AppNotification[]>([]);

  protected readonly groups = computed((): NotificationGroup[] => {
    const list = this.items();
    const today: AppNotification[] = [];
    const yesterday: AppNotification[] = [];
    const earlier: AppNotification[] = [];
    const now = new Date();
    const startToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const startYesterday = new Date(startToday);
    startYesterday.setDate(startYesterday.getDate() - 1);

    for (const n of list) {
      const created = n.createdAt;
      if (!created) {
        earlier.push(n);
        continue;
      }
      if (created >= startToday) {
        today.push(n);
      } else if (created >= startYesterday) {
        yesterday.push(n);
      } else {
        earlier.push(n);
      }
    }

    const out: NotificationGroup[] = [];
    if (today.length) {
      out.push({ key: 'today', labelKey: 'notifications.today', items: today });
    }
    if (yesterday.length) {
      out.push({ key: 'yesterday', labelKey: 'notifications.yesterday', items: yesterday });
    }
    if (earlier.length) {
      out.push({ key: 'earlier', labelKey: 'notifications.earlier', items: earlier });
    }
    return out;
  });

  protected readonly hasUnread = computed(() => this.items().some(isNotificationUnread));

  async ngOnInit(): Promise<void> {
    await this.load();
  }

  protected async onRetry(): Promise<void> {
    await this.load();
  }

  protected iconFor(kind: string): string {
    return notificationIcon(kind);
  }

  protected isUnread(n: AppNotification): boolean {
    return isNotificationUnread(n);
  }

  protected async onMarkAllRead(): Promise<void> {
    if (this.acting() || !this.hasUnread()) {
      return;
    }
    this.acting.set(true);
    try {
      await this.notificationsApi.markAllRead();
      this.items.update((list) =>
        list.map((n) => (n.readAt ? n : { ...n, readAt: new Date() })),
      );
    } catch (error) {
      this.loadError.set(error instanceof Error ? error.message : String(error));
    } finally {
      this.acting.set(false);
    }
  }

  protected async onOpen(n: AppNotification): Promise<void> {
    if (this.acting()) {
      return;
    }
    this.acting.set(true);
    try {
      if (isNotificationUnread(n)) {
        const updated = await this.notificationsApi.markRead(n.id);
        this.items.update((list) => list.map((row) => (row.id === n.id ? updated : row)));
      }
      if (!n.bookingId) {
        return;
      }
      if (isOrgFacingNotificationKind(n.kind)) {
        try {
          const booking = await this.bookings.get(n.bookingId);
          if (booking.organizationId) {
            await this.router.navigate([
              '/business',
              booking.organizationId,
              'bookings',
              n.bookingId,
            ]);
            return;
          }
        } catch {
          // Fall through to consumer booking detail.
        }
      }
      await this.router.navigate(['/bookings', n.bookingId]);
    } catch (error) {
      this.loadError.set(error instanceof Error ? error.message : String(error));
    } finally {
      this.acting.set(false);
    }
  }

  private async load(): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      const page = await this.notificationsApi.list({ pageSize: 50 });
      this.items.set(page.results);
    } catch (error) {
      this.loadError.set(error instanceof Error ? error.message : String(error));
    } finally {
      this.loading.set(false);
    }
  }
}
