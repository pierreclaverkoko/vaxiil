import { ComponentFixture, TestBed } from '@angular/core/testing';

import { VaxiilLogoComponent } from './vaxiil-logo';

describe('VaxiilLogoComponent', () => {
  let fixture: ComponentFixture<VaxiilLogoComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [VaxiilLogoComponent],
    }).compileComponents();

    fixture = TestBed.createComponent(VaxiilLogoComponent);
    await fixture.whenStable();
  });

  it('should create', () => {
    expect(fixture.componentInstance).toBeTruthy();
  });

  it('should render img with logo asset path', () => {
    const img = fixture.nativeElement.querySelector('img') as HTMLImageElement;
    expect(img).toBeTruthy();
    expect(img.alt).toBe('Vaxiil');
    expect(img.getAttribute('src')).toBe('/assets/logo.png');
  });

  it('should render without plate when showPlate is false', async () => {
    fixture.componentRef.setInput('showPlate', false);
    await fixture.whenStable();
    expect(fixture.nativeElement.querySelector('.logo-plate')).toBeNull();
    expect(fixture.nativeElement.querySelector('img')).toBeTruthy();
  });
});
