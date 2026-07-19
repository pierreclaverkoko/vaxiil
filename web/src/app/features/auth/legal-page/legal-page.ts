import { Component, OnInit, inject, signal } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';

import { AuthService } from '@/core/auth/auth.service';
import { ApiError } from '@/core/http/api-error';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';

@Component({
  selector: 'app-legal-page',
  standalone: true,
  imports: [RouterLink, TranslatePipe, ErrorStateComponent],
  templateUrl: './legal-page.html',
  styleUrl: './legal-page.scss',
})
export class LegalPageComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly auth = inject(AuthService);
  private readonly locale = inject(LocaleService);

  protected readonly title = signal('');
  protected readonly body = signal('');
  protected readonly version = signal('');
  protected readonly loading = signal(true);
  protected readonly loadError = signal<string | null>(null);

  async ngOnInit(): Promise<void> {
    const docType =
      this.route.snapshot.data['legalType'] === 'privacy' ? 'privacy' : 'terms';
    this.title.set(
      this.locale.t(docType === 'privacy' ? 'auth.legal.privacyTitle' : 'auth.legal.termsTitle'),
    );
    this.loading.set(true);
    this.loadError.set(null);
    try {
      const doc = await this.auth.fetchLegalDocument(docType);
      this.body.set(doc.body);
      this.version.set(doc.version);
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    } finally {
      this.loading.set(false);
    }
  }
}
