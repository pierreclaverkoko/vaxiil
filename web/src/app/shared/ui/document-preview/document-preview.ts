import { Component, computed, input, output } from '@angular/core';

import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ModalDialogComponent } from '@/shared/ui/modal-dialog/modal-dialog';

@Component({
  selector: 'app-document-preview',
  standalone: true,
  imports: [ButtonComponent, ModalDialogComponent, TranslatePipe],
  template: `
    <app-modal-dialog [open]="open()" [title]="title() || ('common.documentPreview' | t)" (closed)="closed.emit()">
      <div class="doc-preview">
        @if (isImage()) {
          <img [src]="url()!" [alt]="title() || ('common.documentPreview' | t)" />
        } @else if (isPdf()) {
          <iframe [src]="url()!" title="{{ title() || ('common.documentPreview' | t) }}"></iframe>
        } @else if (url()) {
          <p>{{ 'common.documentPreviewFallback' | t }}</p>
          <a [href]="url()!" target="_blank" rel="noopener">{{ 'common.openInNewTab' | t }}</a>
        }
      </div>
      <div class="doc-preview__actions">
        <app-button type="button" variant="secondary" (click)="closed.emit()">{{
          'common.close' | t
        }}</app-button>
      </div>
    </app-modal-dialog>
  `,
  styles: `
    .doc-preview {
      display: grid;
      place-items: center;
      min-height: 16rem;
      max-height: min(70vh, 40rem);
      overflow: auto;
      background: var(--color-surface-container-lowest);
      border-radius: var(--radius-default);
    }
    .doc-preview img,
    .doc-preview iframe {
      width: 100%;
      min-height: 20rem;
      border: 0;
    }
    .doc-preview img {
      object-fit: contain;
      max-height: min(70vh, 40rem);
    }
    .doc-preview__actions {
      margin-top: var(--space-3);
      display: flex;
      justify-content: flex-end;
    }
  `,
})
export class DocumentPreviewComponent {
  readonly open = input(false);
  readonly url = input<string | null>(null);
  readonly title = input('');
  readonly closed = output<void>();

  protected readonly isImage = computed(() => {
    const value = (this.url() || '').toLowerCase();
    return /\.(png|jpe?g|gif|webp|bmp)(\?|$)/.test(value) || value.includes('image');
  });

  protected readonly isPdf = computed(() => {
    const value = (this.url() || '').toLowerCase();
    return value.includes('.pdf') || value.includes('application/pdf');
  });
}
