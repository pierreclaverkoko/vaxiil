import { ComponentFixture, TestBed } from '@angular/core/testing';

import { ChoiceEnumChipComponent } from './choice-enum-chip';

describe('ChoiceEnumChipComponent', () => {
  let fixture: ComponentFixture<ChoiceEnumChipComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [ChoiceEnumChipComponent],
    }).compileComponents();

    fixture = TestBed.createComponent(ChoiceEnumChipComponent);
  });

  it('should render title for a known css token', async () => {
    fixture.componentRef.setInput('choice', {
      value: 'a',
      title: 'Active',
      css: 'success',
    });
    await fixture.whenStable();
    const chip = fixture.nativeElement.querySelector('.chip') as HTMLElement;
    expect(chip.textContent?.trim()).toBe('Active');
    expect(chip.getAttribute('data-css')).toBe('success');
  });

  it('should fall back to default for unknown css', async () => {
    fixture.componentRef.setInput('choice', {
      value: 'x',
      title: 'Mystery',
      css: 'neon-purple',
    });
    await fixture.whenStable();
    const chip = fixture.nativeElement.querySelector('.chip') as HTMLElement;
    expect(chip.getAttribute('data-css')).toBe('default');
  });

  it('should render nothing when choice is null', async () => {
    fixture.componentRef.setInput('choice', null);
    await fixture.whenStable();
    expect(fixture.nativeElement.querySelector('.chip')).toBeNull();
  });
});
