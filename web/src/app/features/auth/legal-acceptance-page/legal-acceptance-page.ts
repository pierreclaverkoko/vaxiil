import { Component, OnInit, inject, signal } from '@angular/core';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';

import { AuthService } from '@/core/auth/auth.service';
import { ApiError } from '@/core/http/api-error';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { ButtonComponent } from '@/shared/ui/button/button';

@Component({
  selector: 'app-legal-acceptance-page',
  standalone: true,
  imports: [RouterLink, ButtonComponent, TranslatePipe],
  templateUrl: './legal-acceptance-page.html',
  styleUrl: './legal-acceptance-page.scss',
})
export class LegalAcceptancePageComponent implements OnInit {
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  private readonly route = inject(ActivatedRoute);
  private readonly locale = inject(LocaleService);

  protected readonly termsVersion = signal<string | null>(null);
  protected readonly privacyVersion = signal<string | null>(null);
  protected readonly accepted = signal(false);
  protected readonly submitting = signal(false);
  protected readonly formError = signal<string | null>(null);

  async ngOnInit(): Promise<void> {
    const user = this.auth.currentUser();
    if (user && !user.legal?.needsAcceptance) {
      await this.router.navigateByUrl('/discover');
      return;
    }
    try {
      const meta = await this.auth.fetchMetadata();
      this.termsVersion.set(meta.termsVersion);
      this.privacyVersion.set(meta.privacyVersion);
    } catch (error) {
      this.formError.set((error as ApiError).message);
    }
  }

  protected async onAccept(): Promise<void> {
    const terms = this.termsVersion();
    const privacy = this.privacyVersion();
    if (!this.accepted() || !terms || !privacy || this.submitting()) {
      this.formError.set(this.locale.t('auth.register.acceptLegalRequired'));
      return;
    }
    this.submitting.set(true);
    this.formError.set(null);
    try {
      await this.auth.acceptLegal(terms, privacy);
      const returnUrl = this.route.snapshot.queryParamMap.get('returnUrl') || '/discover';
      await this.router.navigateByUrl(returnUrl);
    } catch (error) {
      this.formError.set((error as ApiError).message);
    } finally {
      this.submitting.set(false);
    }
  }
}
