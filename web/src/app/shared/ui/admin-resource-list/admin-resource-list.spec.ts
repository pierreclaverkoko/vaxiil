import { signal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { beforeEach, describe, expect, it } from 'vitest';

import { LocaleService } from '@/core/i18n/locale.service';

import { AdminResourceListComponent } from './admin-resource-list';

describe('AdminResourceListComponent', () => {
  let fixture: ComponentFixture<AdminResourceListComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [AdminResourceListComponent],
      providers: [
        {
          provide: LocaleService,
          useValue: {
            locale: signal('en'),
            t: (key: string) => key,
          },
        },
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(AdminResourceListComponent);
    fixture.componentRef.setInput('columns', [
      { key: 'name', label: 'Name', sortable: true },
    ]);
    fixture.componentRef.setInput('rowCount', 2);
    fixture.componentRef.setInput('totalCount', 20);
    fixture.componentRef.setInput('page', 1);
    fixture.componentRef.setInput('pageSize', 20);
    fixture.detectChanges();
  });

  it('renders search and pagination chrome', () => {
    const el: HTMLElement = fixture.nativeElement;
    expect(el.querySelector('input[type="search"]')).toBeTruthy();
    expect(el.textContent).toContain('1–2 / 20');
  });
});
