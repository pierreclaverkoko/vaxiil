import { Component, inject, signal } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { map } from 'rxjs';

import { ApiError } from '@/core/http/api-error';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { MessagingService } from '@/features/messages/messaging.service';
import { ButtonComponent } from '@/shared/ui/button/button';
import { environment } from '../../../../environments/environment';

@Component({
  selector: 'app-profile-stub-page',
  standalone: true,
  imports: [RouterLink, TranslatePipe, ButtonComponent],
  templateUrl: './profile-stub-page.html',
  styleUrl: './profile-stub-page.scss',
})
export class ProfileStubPageComponent {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly messaging = inject(MessagingService);

  protected readonly titleKey = toSignal(
    this.route.data.pipe(map((d) => (d['titleKey'] as string) ?? 'profile.title')),
    { initialValue: 'profile.title' },
  );

  protected readonly bodyKey = toSignal(
    this.route.data.pipe(map((d) => (d['bodyKey'] as string) ?? 'profile.stubFallback')),
    { initialValue: 'profile.stubFallback' },
  );

  protected readonly showContact = toSignal(
    this.route.data.pipe(map((d) => Boolean(d['showContact']))),
    { initialValue: false },
  );

  protected readonly supportEmail = environment.supportEmail;
  protected readonly supportPhone = environment.supportPhone;
  protected readonly chatBusy = signal(false);
  protected readonly chatError = signal<string | null>(null);

  protected async onStartSupportChat(): Promise<void> {
    if (this.chatBusy()) {
      return;
    }
    this.chatBusy.set(true);
    this.chatError.set(null);
    try {
      const conversation = await this.messaging.openPlatformSupport();
      await this.router.navigate(['/messages', conversation.id]);
    } catch (error) {
      this.chatError.set((error as ApiError).message);
    } finally {
      this.chatBusy.set(false);
    }
  }
}
