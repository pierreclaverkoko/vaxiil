import { Component, OnInit, computed, inject, signal } from '@angular/core';

import { ApiError } from '@/core/http/api-error';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { StaffApiService } from '@/features/staff/staff-api.service';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';
import { InputComponent } from '@/shared/ui/input/input';
import { OptionCardGroupComponent, OptionCardItem } from '@/shared/ui/option-card-group/option-card-group';

@Component({
  selector: 'app-staff-settlements-page',
  standalone: true,
  imports: [
    ButtonComponent,
    ErrorStateComponent,
    InputComponent,
    OptionCardGroupComponent,
    TranslatePipe,
  ],
  templateUrl: './staff-settlements-page.html',
  styleUrl: '../staff-queue.scss',
})
export class StaffSettlementsPageComponent implements OnInit {
  private readonly api = inject(StaffApiService);
  private readonly locale = inject(LocaleService);

  protected readonly rows = signal<Array<Record<string, unknown>>>([]);
  protected readonly filterStatus = signal('R');
  protected readonly loading = signal(true);
  protected readonly loadError = signal<string | null>(null);
  protected readonly actionMessage = signal<string | null>(null);
  protected readonly actionError = signal<string | null>(null);
  protected readonly busyId = signal<string | null>(null);
  protected readonly staffNote = signal('');
  protected readonly selectedFile = signal<File | null>(null);

  protected readonly statusOptions = computed<OptionCardItem[]>(() => {
    this.locale.locale();
    return [
      { value: '', title: this.locale.t('staff.filterAll'), icon: 'filter_list' },
      {
        value: 'R',
        title: this.locale.t('staff.settlements.statusRequested'),
        icon: 'hourglass_top',
      },
      {
        value: 'P',
        title: this.locale.t('staff.settlements.statusProcessing'),
        icon: 'sync',
      },
      {
        value: 'C',
        title: this.locale.t('staff.settlements.statusCompleted'),
        icon: 'check_circle',
      },
      {
        value: 'X',
        title: this.locale.t('staff.settlements.statusRejected'),
        icon: 'cancel',
      },
    ];
  });

  async ngOnInit(): Promise<void> {
    await this.load();
  }

  protected onFilter(value: string): void {
    this.filterStatus.set(value);
    void this.load();
  }

  protected onFileSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0] ?? null;
    this.selectedFile.set(file);
  }

  protected async onComplete(id: string): Promise<void> {
    const file = this.selectedFile();
    if (!file) {
      this.actionError.set(this.locale.t('staff.settlements.imageRequired'));
      return;
    }
    this.busyId.set(id);
    this.actionError.set(null);
    try {
      const form = new FormData();
      form.append('confirmation_image', file);
      const note = this.staffNote().trim();
      if (note) {
        form.append('staff_note', note);
      }
      await this.api.completeSettlement(id, form);
      this.actionMessage.set(this.locale.t('staff.settlements.completed'));
      this.selectedFile.set(null);
      this.staffNote.set('');
      await this.load();
    } catch (error) {
      this.actionError.set((error as ApiError).message);
    } finally {
      this.busyId.set(null);
    }
  }

  protected async onReject(id: string): Promise<void> {
    const note = this.staffNote().trim();
    if (!note) {
      this.actionError.set(this.locale.t('staff.settlements.noteRequired'));
      return;
    }
    this.busyId.set(id);
    this.actionError.set(null);
    try {
      await this.api.rejectSettlement(id, note);
      this.actionMessage.set(this.locale.t('staff.settlements.rejected'));
      this.staffNote.set('');
      await this.load();
    } catch (error) {
      this.actionError.set((error as ApiError).message);
    } finally {
      this.busyId.set(null);
    }
  }

  protected statusTitle(row: Record<string, unknown>): string {
    const status = row['status'];
    if (status && typeof status === 'object' && 'title' in status) {
      return String((status as { title: unknown }).title);
    }
    return String(status ?? '');
  }

  protected rowId(row: Record<string, unknown>): string {
    return String(row['id'] ?? '');
  }

  private async load(): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      const status = this.filterStatus();
      this.rows.set(await this.api.listSettlements(status ? { status } : {}));
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    } finally {
      this.loading.set(false);
    }
  }
}
