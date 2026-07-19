import { Component, OnInit, inject, signal } from '@angular/core';
import { ActivatedRoute } from '@angular/router';

import { ApiError } from '@/core/http/api-error';
import { LocaleService } from '@/core/i18n/locale.service';
import { TranslatePipe } from '@/core/i18n/translate.pipe';
import { OrganizationsService } from '@/features/business/organizations.service';
import { TeamMember, teamMemberDisplayName } from '@/models/organization';
import { ButtonComponent } from '@/shared/ui/button/button';
import { ChoiceEnumChipComponent } from '@/shared/ui/choice-enum-chip/choice-enum-chip';
import { EmptyStateComponent } from '@/shared/ui/empty-state/empty-state';
import { ErrorStateComponent } from '@/shared/ui/error-state/error-state';

@Component({
  selector: 'app-business-team-page',
  standalone: true,
  imports: [
    ButtonComponent,
    ChoiceEnumChipComponent,
    EmptyStateComponent,
    ErrorStateComponent,
    TranslatePipe,
  ],
  templateUrl: './business-team-page.html',
  styleUrl: './business-team-page.scss',
})
export class BusinessTeamPageComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly orgsApi = inject(OrganizationsService);
  private readonly locale = inject(LocaleService);

  protected readonly members = signal<TeamMember[]>([]);
  protected readonly orgId = signal<string | null>(null);
  protected readonly inviteEmail = signal('');
  protected readonly inviteRole = signal('T');
  protected readonly loading = signal(true);
  protected readonly saving = signal(false);
  protected readonly loadError = signal<string | null>(null);
  protected readonly actionError = signal<string | null>(null);
  protected readonly actionSuccess = signal<string | null>(null);

  protected readonly displayName = teamMemberDisplayName;

  async ngOnInit(): Promise<void> {
    const orgId = this.route.snapshot.paramMap.get('orgId');
    if (!orgId) {
      this.loadError.set(this.locale.t('business.errors.missingOrgId'));
      this.loading.set(false);
      return;
    }
    this.orgId.set(orgId);
    await this.load(orgId);
  }

  protected onRetry(): void {
    const orgId = this.route.snapshot.paramMap.get('orgId');
    if (orgId) {
      void this.load(orgId);
    }
  }

  protected async onInvite(event: Event): Promise<void> {
    event.preventDefault();
    const orgId = this.orgId();
    const email = this.inviteEmail().trim();
    if (!orgId || !email || this.saving()) {
      return;
    }
    this.actionError.set(null);
    this.actionSuccess.set(null);
    this.saving.set(true);
    try {
      await this.orgsApi.inviteTeamMember(orgId, { email, role: this.inviteRole() });
      this.inviteEmail.set('');
      this.actionSuccess.set(this.locale.t('business.team.invited'));
      await this.load(orgId);
    } catch (error) {
      this.actionError.set((error as ApiError).message);
    } finally {
      this.saving.set(false);
    }
  }

  protected async onRoleChange(member: TeamMember, event: Event): Promise<void> {
    const orgId = this.orgId();
    const role = (event.target as HTMLSelectElement).value;
    if (!orgId || !role || role === member.membershipRole?.value || this.saving()) {
      return;
    }
    this.saving.set(true);
    this.actionError.set(null);
    try {
      const updated = await this.orgsApi.updateTeamMemberRole(orgId, member.id, role);
      this.members.update((members) =>
        members.map((item) => (item.id === member.id ? updated : item)),
      );
      this.actionSuccess.set(this.locale.t('business.team.roleUpdated'));
    } catch (error) {
      this.actionError.set((error as ApiError).message);
    } finally {
      this.saving.set(false);
    }
  }

  protected async onRemove(member: TeamMember): Promise<void> {
    const orgId = this.orgId();
    if (!orgId || this.saving() || !confirm(this.locale.t('business.team.confirmRemove'))) {
      return;
    }
    this.saving.set(true);
    this.actionError.set(null);
    try {
      await this.orgsApi.removeTeamMember(orgId, member.id);
      this.members.update((members) => members.filter((item) => item.id !== member.id));
      this.actionSuccess.set(this.locale.t('business.team.removed'));
    } catch (error) {
      this.actionError.set((error as ApiError).message);
    } finally {
      this.saving.set(false);
    }
  }

  private async load(orgId: string): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      this.members.set(await this.orgsApi.team(orgId));
    } catch (error) {
      this.loadError.set((error as ApiError).message);
    } finally {
      this.loading.set(false);
    }
  }
}
