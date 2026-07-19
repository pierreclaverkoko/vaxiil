import { Component, inject } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { ActivatedRoute } from '@angular/router';
import { map } from 'rxjs';

import { EmptyStateComponent } from '@/shared/ui/empty-state/empty-state';

@Component({
  selector: 'app-business-section-stub-page',
  standalone: true,
  imports: [EmptyStateComponent],
  templateUrl: './business-section-stub-page.html',
  styleUrl: './business-section-stub-page.scss',
})
export class BusinessSectionStubPageComponent {
  private readonly route = inject(ActivatedRoute);

  protected readonly title = toSignal(
    this.route.data.pipe(map((d) => (d['title'] as string) ?? 'Section')),
    { initialValue: 'Section' },
  );

  protected readonly message = toSignal(
    this.route.data.pipe(
      map((d) => (d['message'] as string) ?? 'Coming in Phase W4.'),
    ),
    { initialValue: 'Coming in Phase W4.' },
  );

  protected readonly icon = toSignal(
    this.route.data.pipe(map((d) => (d['icon'] as string) ?? 'spa')),
    { initialValue: 'spa' },
  );
}
