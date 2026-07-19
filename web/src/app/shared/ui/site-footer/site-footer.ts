import { Component } from '@angular/core';
import { RouterLink } from '@angular/router';

import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { VaxiilLogoComponent } from '@/shared/ui/vaxiil-logo/vaxiil-logo';

@Component({
  selector: 'app-site-footer',
  standalone: true,
  imports: [RouterLink, TranslatePipe, VaxiilLogoComponent],
  templateUrl: './site-footer.html',
  styleUrl: './site-footer.scss',
})
export class SiteFooterComponent {
  protected readonly year = new Date().getFullYear();
}
