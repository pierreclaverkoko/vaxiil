import { Component, input } from '@angular/core';

import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { LOCATION_TYPE_ICONS } from '@/models/booking';

@Component({
  selector: 'app-service-card-meta',
  standalone: true,
  imports: [TranslatePipe],
  templateUrl: './service-card-meta.html',
  styleUrl: './service-card-meta.scss',
})
export class ServiceCardMetaComponent {
  readonly cityName = input<string | null>(null);
  readonly locationTypes = input<string[]>([]);

  protected iconFor(code: string): string {
    return LOCATION_TYPE_ICONS[code] ?? 'place';
  }

  protected labelKey(code: string): string {
    switch (code) {
      case 'H':
        return 'bookings.locationHome';
      case 'V':
        return 'bookings.locationVirtual';
      case 'B':
        return 'bookings.locationMobile';
      case 'O':
      default:
        return 'bookings.locationOffice';
    }
  }
}
