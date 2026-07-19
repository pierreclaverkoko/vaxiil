import { Component, OnInit, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { AuthService } from '@/core/auth/auth.service';
import { ApiError } from '@/core/http/api-error';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { AuthUser } from '@/models/auth-user';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';
import { InputComponent } from '@/shared/ui/input/input';

@Component({
  selector: 'app-personal-info-page',
  standalone: true,
  imports: [ButtonComponent, ErrorStateComponent, InputComponent, TranslatePipe],
  templateUrl: './personal-info-page.html',
  styleUrl: './personal-info-page.scss',
})
export class PersonalInfoPageComponent implements OnInit {
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);

  protected readonly firstName = signal('');
  protected readonly lastName = signal('');
  protected readonly phone = signal('');
  protected readonly dateOfBirth = signal('');
  protected readonly sex = signal('');
  protected readonly saving = signal(false);
  protected readonly formError = signal<string | null>(null);
  protected readonly formSuccess = signal<string | null>(null);
  protected readonly loadError = signal<string | null>(null);

  async ngOnInit(): Promise<void> {
    try {
      const profile = this.auth.currentUser() ?? (await this.auth.fetchProfile());
      this.hydrate(profile);
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    }
  }

  protected async onSave(event: Event): Promise<void> {
    event.preventDefault();
    if (this.saving()) {
      return;
    }
    this.formError.set(null);
    this.formSuccess.set(null);
    this.saving.set(true);
    try {
      await this.auth.updateProfile({
        first_name: this.firstName().trim(),
        last_name: this.lastName().trim(),
        phone: this.phone().trim(),
        date_of_birth: this.dateOfBirth().trim() || null,
        sex: this.sex().trim() || null,
      });
      await this.router.navigateByUrl('/profile', { replaceUrl: true });
    } catch (error) {
      this.formError.set((error as ApiError).message);
    } finally {
      this.saving.set(false);
    }
  }

  private hydrate(user: AuthUser): void {
    this.firstName.set(user.firstName ?? '');
    this.lastName.set(user.lastName ?? '');
    this.phone.set(user.phone ?? '');
    this.dateOfBirth.set(user.dateOfBirth ?? '');
    this.sex.set(user.sex?.value != null ? String(user.sex.value) : '');
  }
}
