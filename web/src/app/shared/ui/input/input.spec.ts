import { ComponentFixture, TestBed } from '@angular/core/testing';

import { LocaleService } from '@/core/i18n/locale.service';

import { InputComponent } from './input';

describe('InputComponent', () => {
  let fixture: ComponentFixture<InputComponent>;
  let component: InputComponent;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [InputComponent],
      providers: [
        {
          provide: LocaleService,
          useValue: {
            t: (key: string) => key,
            locale: () => 'en',
          },
        },
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(InputComponent);
    component = fixture.componentInstance;
    fixture.componentRef.setInput('id', 'pwd');
    fixture.componentRef.setInput('type', 'password');
    fixture.detectChanges();
  });

  it('toggles password visibility on click', () => {
    expect(component.effectiveType()).toBe('password');
    const btn = fixture.nativeElement.querySelector('.field__toggle') as HTMLButtonElement;
    expect(btn).toBeTruthy();
    btn.click();
    fixture.detectChanges();
    expect(component.effectiveType()).toBe('text');
    expect(component.visibilityIcon()).toBe('visibility_off');
  });
});
