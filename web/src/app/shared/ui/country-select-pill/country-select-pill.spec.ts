import { ComponentFixture, TestBed } from '@angular/core/testing';
import { describe, expect, it } from 'vitest';

import { CountryBrief } from '@/models/organization';

import { CountrySelectPillComponent } from './country-select-pill';

describe('CountrySelectPillComponent', () => {
  const countries: CountryBrief[] = [
    { id: '1', isoCode2: 'gb', name: 'United Kingdom', flag: 'https://example.com/gb.png' },
    { id: '2', isoCode2: 'us', name: 'United States', flag: null },
  ];

  async function setup(value = '1'): Promise<ComponentFixture<CountrySelectPillComponent>> {
    await TestBed.configureTestingModule({
      imports: [CountrySelectPillComponent],
    }).compileComponents();
    const fixture = TestBed.createComponent(CountrySelectPillComponent);
    fixture.componentRef.setInput('countries', countries);
    fixture.componentRef.setInput('value', value);
    fixture.componentRef.setInput('ariaLabel', 'Country');
    fixture.detectChanges();
    return fixture;
  }

  it('shows ISO code and flag for the selected country', async () => {
    const fixture = await setup('1');
    const el = fixture.nativeElement as HTMLElement;
    expect(el.textContent).toContain('GB');
    expect(el.querySelector('img')?.getAttribute('src')).toBe('https://example.com/gb.png');
  });

  it('falls back to ISO badge when flag is missing', async () => {
    const fixture = await setup('2');
    const el = fixture.nativeElement as HTMLElement;
    expect(el.textContent).toContain('US');
    expect(el.querySelector('.country-pill__flag-fallback')?.textContent?.trim()).toBe('US');
  });

  it('emits valueChange when an option is chosen', async () => {
    const fixture = await setup('1');
    const emitted: string[] = [];
    fixture.componentInstance.valueChange.subscribe((id) => emitted.push(id));
    fixture.nativeElement.querySelector('.country-pill__trigger')?.click();
    fixture.detectChanges();
    const options = fixture.nativeElement.querySelectorAll('.country-pill__option');
    (options[1] as HTMLButtonElement).click();
    expect(emitted).toEqual(['2']);
  });
});
