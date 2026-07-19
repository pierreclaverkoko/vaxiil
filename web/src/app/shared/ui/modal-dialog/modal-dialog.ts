import { Component, HostListener, input, output } from '@angular/core';

import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { ButtonComponent } from '@/shared/ui/button/button';

@Component({
  selector: 'app-modal-dialog',
  standalone: true,
  imports: [ButtonComponent, TranslatePipe],
  templateUrl: './modal-dialog.html',
  styleUrl: './modal-dialog.scss',
})
export class ModalDialogComponent {
  readonly open = input(false);
  readonly title = input('');
  readonly closeLabel = input('common.close');
  readonly closed = output<void>();

  @HostListener('document:keydown.escape')
  onEscape(): void {
    if (this.open()) {
      this.closed.emit();
    }
  }
}
