import { Component, computed, inject } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { ActivatedRoute } from '@angular/router';
import { map } from 'rxjs/operators';

import { ScopedNotificationsPageComponent } from '@/features/notifications/scoped-notifications-page/scoped-notifications-page';

@Component({
  selector: 'app-business-notifications-page',
  standalone: true,
  imports: [ScopedNotificationsPageComponent],
  template: `<app-scoped-notifications-page [organizationId]="orgId()" />`,
})
export class BusinessNotificationsPageComponent {
  private readonly route = inject(ActivatedRoute);
  private readonly params = toSignal(
    this.route.paramMap.pipe(map((p) => p.get('orgId'))),
    { initialValue: this.route.snapshot.paramMap.get('orgId') },
  );
  protected readonly orgId = computed(() => this.params());
}
