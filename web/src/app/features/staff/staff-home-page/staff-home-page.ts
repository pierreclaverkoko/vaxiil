import { Component } from '@angular/core';
import { RouterLink } from '@angular/router';

import { TranslatePipe } from '@/core/i18n/translate.pipe';

@Component({
  selector: 'app-staff-home-page',
  standalone: true,
  imports: [RouterLink, TranslatePipe],
  templateUrl: './staff-home-page.html',
  styleUrl: './staff-home-page.scss',
})
export class StaffHomePageComponent {
  protected readonly links = [
    { path: '/staff/users', labelKey: 'shell.staff.users', icon: 'badge' },
    { path: '/staff/organizations', labelKey: 'shell.staff.organizations', icon: 'domain' },
    { path: '/staff/taxonomy', labelKey: 'shell.staff.taxonomy', icon: 'category' },
    { path: '/staff/bookings', labelKey: 'shell.staff.bookings', icon: 'event_note' },
    { path: '/staff/payments', labelKey: 'shell.staff.payments', icon: 'payments' },
  ] as const;
}
