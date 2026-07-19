import { Component, input } from '@angular/core';

@Component({
  selector: 'app-badge',
  standalone: true,
  templateUrl: './badge.html',
  styleUrl: './badge.scss',
})
export class BadgeComponent {
  readonly tone = input<'neutral' | 'primary' | 'warning'>('neutral');
}
