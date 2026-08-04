import {
  Component,
  ElementRef,
  HostListener,
  computed,
  inject,
  input,
  output,
  signal,
} from '@angular/core';

import { CountryBrief } from '@/models/organization';

@Component({
  selector: 'app-country-select-pill',
  standalone: true,
  templateUrl: './country-select-pill.html',
  styleUrl: './country-select-pill.scss',
})
export class CountrySelectPillComponent {
  private readonly host = inject(ElementRef<HTMLElement>);

  readonly countries = input.required<CountryBrief[]>();
  readonly value = input<string>('');
  readonly ariaLabel = input<string>('');
  readonly searchPlaceholder = input<string>('Search');
  readonly valueChange = output<string>();

  protected readonly open = signal(false);
  protected readonly query = signal('');

  protected readonly selected = computed(() => {
    const id = this.value();
    return this.countries().find((c) => c.id === id) ?? this.countries()[0] ?? null;
  });

  protected readonly displayCode = computed(() => {
    const code = this.selected()?.isoCode2?.trim() ?? '';
    return code ? code.toUpperCase() : '—';
  });

  protected readonly flagUrl = computed(() => this.selected()?.flag ?? null);

  protected readonly filtered = computed(() => {
    const q = this.query().trim().toLowerCase();
    const list = this.countries();
    if (!q) {
      return list;
    }
    return list.filter((c) => {
      const name = (c.name || '').toLowerCase();
      const code = (c.isoCode2 || '').toLowerCase();
      return name.includes(q) || code.includes(q);
    });
  });

  @HostListener('document:click', ['$event'])
  onDocumentClick(event: MouseEvent): void {
    if (!this.open()) {
      return;
    }
    if (!this.host.nativeElement.contains(event.target as Node)) {
      this.open.set(false);
      this.query.set('');
    }
  }

  @HostListener('document:keydown.escape')
  onEscape(): void {
    this.open.set(false);
    this.query.set('');
  }

  protected toggle(): void {
    if (!this.countries().length) {
      return;
    }
    const next = !this.open();
    this.open.set(next);
    if (!next) {
      this.query.set('');
    }
  }

  protected onQueryInput(event: Event): void {
    const target = event.target as HTMLInputElement;
    this.query.set(target.value);
  }

  protected selectCountry(country: CountryBrief): void {
    this.valueChange.emit(country.id);
    this.open.set(false);
    this.query.set('');
  }

  protected isSelected(country: CountryBrief): boolean {
    return country.id === this.value() || country.id === this.selected()?.id;
  }
}
