import { Component, computed, input } from '@angular/core';

import { ChoiceEnum, normalizeChoiceEnumCss } from '@/models/choice-enum';

@Component({
  selector: 'app-choice-enum-chip',
  standalone: true,
  templateUrl: './choice-enum-chip.html',
  styleUrl: './choice-enum-chip.scss',
})
export class ChoiceEnumChipComponent {
  readonly choice = input<ChoiceEnum | null>(null);
  readonly compact = input(true);

  protected readonly cssToken = computed(() =>
    normalizeChoiceEnumCss(this.choice()?.css ?? 'secondary'),
  );
}
