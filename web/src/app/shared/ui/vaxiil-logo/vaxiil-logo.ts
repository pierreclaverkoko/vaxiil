import { Component, input } from '@angular/core';

/** Branded logo with optional light plate for contrast on gradients / sage UI. */
@Component({
  selector: 'app-vaxiil-logo',
  standalone: true,
  templateUrl: './vaxiil-logo.html',
  styleUrl: './vaxiil-logo.scss',
})
export class VaxiilLogoComponent {
  static readonly assetPath = '/assets/logo.png';

  readonly height = input(72);
  readonly width = input<number | null>(null);
  readonly showPlate = input(true);
  readonly platePadding = input('12px');
  readonly borderRadius = input(28);
  readonly circularPlate = input(false);

  protected readonly assetPath = VaxiilLogoComponent.assetPath;
}
