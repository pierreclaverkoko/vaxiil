import { signal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { LocaleService } from '@/core/i18n/locale.service';
import { PaymentsService } from '@/features/bookings/payments.service';

import { TransactionsListPageComponent } from './transactions-list-page';

describe('TransactionsListPageComponent', () => {
  let fixture: ComponentFixture<TransactionsListPageComponent>;
  const listTransactions = vi.fn().mockResolvedValue({
    count: 0,
    next: null,
    previous: null,
    results: [],
  });

  beforeEach(async () => {
    listTransactions.mockClear();
    await TestBed.configureTestingModule({
      imports: [TransactionsListPageComponent],
      providers: [
        provideRouter([]),
        {
          provide: PaymentsService,
          useValue: { listTransactions },
        },
        {
          provide: LocaleService,
          useValue: {
            t: (key: string) => key,
            locale: signal('en'),
          },
        },
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(TransactionsListPageComponent);
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();
  });

  it('loads and shows empty state', () => {
    expect(listTransactions).toHaveBeenCalled();
    const el: HTMLElement = fixture.nativeElement;
    expect(el.textContent).toContain('transactions.empty');
  });
});
