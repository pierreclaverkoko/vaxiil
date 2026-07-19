import { Component } from '@angular/core';
import { RouterLink } from '@angular/router';

import { StitchImages } from '@/core/constants/stitch-images';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { ButtonComponent } from '@/shared/ui/button/button';

@Component({
  selector: 'app-onboarding-page',
  standalone: true,
  imports: [RouterLink, ButtonComponent, TranslatePipe],
  templateUrl: './onboarding-page.html',
  styleUrl: './onboarding-page.scss',
})
export class OnboardingPageComponent {
  protected readonly splashImages = [
    StitchImages.splashCollage1,
    StitchImages.splashCollage2,
    StitchImages.splashCollage3,
    StitchImages.splashCollage4,
  ] as const;
}
