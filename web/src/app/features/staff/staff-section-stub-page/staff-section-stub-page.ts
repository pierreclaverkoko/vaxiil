import { Component, inject } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { ActivatedRoute } from '@angular/router';
import { map } from 'rxjs';

import { EmptyStateComponent } from '@/shared/ui/empty-state/empty-state';

@Component({
  selector: 'app-staff-section-stub-page',
  standalone: true,
  imports: [EmptyStateComponent],
  templateUrl: './staff-section-stub-page.html',
  styleUrl: './staff-section-stub-page.scss',
})
export class StaffSectionStubPageComponent {
  private readonly route = inject(ActivatedRoute);

  protected readonly title = toSignal(
    this.route.data.pipe(map((d) => (d['title'] as string) ?? 'Section')),
    { initialValue: 'Section' },
  );

  protected readonly message = toSignal(
    this.route.data.pipe(map((d) => (d['message'] as string) ?? 'Coming in Phase W5.')),
    { initialValue: 'Coming in Phase W5.' },
  );

  protected readonly icon = toSignal(
    this.route.data.pipe(map((d) => (d['icon'] as string) ?? 'badge')),
    { initialValue: 'badge' },
  );
}
