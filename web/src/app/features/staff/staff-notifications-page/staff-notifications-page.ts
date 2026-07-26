import { Component } from '@angular/core';

import { ScopedNotificationsPageComponent } from '@/features/notifications/scoped-notifications-page/scoped-notifications-page';

@Component({
  selector: 'app-staff-notifications-page',
  standalone: true,
  imports: [ScopedNotificationsPageComponent],
  template: `<app-scoped-notifications-page scope="staff" />`,
})
export class StaffNotificationsPageComponent {}
