import { Component, inject } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { map } from 'rxjs';

import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { environment } from '../../../../environments/environment';

@Component({
  selector: 'app-profile-stub-page',
  standalone: true,
  imports: [RouterLink, TranslatePipe],
  templateUrl: './profile-stub-page.html',
  styleUrl: './profile-stub-page.scss',
})
export class ProfileStubPageComponent {
  private readonly route = inject(ActivatedRoute);

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
}
