import { ComponentFixture, TestBed } from '@angular/core/testing';

import { IconAutocompleteFieldComponent } from './icon-autocomplete';

describe('IconAutocompleteFieldComponent', () => {
  let fixture: ComponentFixture<IconAutocompleteFieldComponent>;
  let component: IconAutocompleteFieldComponent;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [IconAutocompleteFieldComponent],
    }).compileComponents();

    fixture = TestBed.createComponent(IconAutocompleteFieldComponent);
    component = fixture.componentInstance;
    fixture.componentRef.setInput('id', 'icon-test');
    fixture.detectChanges();
  });

  it('filters options by query and pick updates value', () => {
    const input = fixture.nativeElement.querySelector('input') as HTMLInputElement;
    input.dispatchEvent(new Event('focus'));
    input.value = 'spark';
    input.dispatchEvent(new Event('input'));
    fixture.detectChanges();

    const names = component['filtered']();
    expect(names).toContain('sparkles');
    expect(names.every((n) => n.includes('spark'))).toBe(true);

    component['pick']('sparkles');
    fixture.detectChanges();
    expect(component.value()).toBe('sparkles');
    expect(component['previewSymbol']()).toBe('auto_awesome');
  });

  it('clears value', () => {
    component.value.set('heart');
    fixture.detectChanges();
    component['clear']();
    expect(component.value()).toBe('');
  });
});
