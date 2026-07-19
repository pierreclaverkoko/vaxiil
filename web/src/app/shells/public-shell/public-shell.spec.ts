import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';

import { PublicShellComponent } from './public-shell';

describe('PublicShellComponent', () => {
  let fixture: ComponentFixture<PublicShellComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PublicShellComponent],
      providers: [provideRouter([])],
    }).compileComponents();

    fixture = TestBed.createComponent(PublicShellComponent);
    await fixture.whenStable();
  });

  it('should create', () => {
    expect(fixture.componentInstance).toBeTruthy();
  });

  it('should render the brand logo', () => {
    const img = fixture.nativeElement.querySelector(
      '.public-shell__brand img',
    ) as HTMLImageElement;
    expect(img?.getAttribute('src')).toBe('/assets/logo.png');
  });

  it('should render a stitch panel image', () => {
    const img = fixture.nativeElement.querySelector(
      '.public-shell__visual-img',
    ) as HTMLImageElement;
    expect(img?.getAttribute('src')).toContain('/assets/images/');
  });

  it('should keep the right content column as the scroll container', () => {
    const content = fixture.nativeElement.querySelector(
      '.public-shell__content',
    ) as HTMLElement;
    expect(getComputedStyle(content).overflowY).toBe('auto');
  });
});
