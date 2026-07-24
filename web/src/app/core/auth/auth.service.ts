import { HttpClient } from '@angular/common/http';
import { Injectable, computed, inject, signal } from '@angular/core';
import { firstValueFrom } from 'rxjs';

import { ApiPaths } from '@/core/constants/api-paths';
import { mapHttpError } from '@/core/http/api-error';
import { TokenStorageService } from '@/core/auth/token-storage.service';
import { LocaleService } from '@/core/i18n/locale.service';
import { AuthUser, parseAuthUser } from '@/models/auth-user';
import { environment } from '../../../environments/environment';

export interface LoginRequest {
  email: string;
  password: string;
}

export interface RegisterRequest {
  email: string;
  username: string;
  password: string;
  passwordConfirm: string;
  firstName?: string;
  lastName?: string;
  phone?: string;
  role?: string;
  acceptedTermsVersion: string;
  acceptedPrivacyVersion: string;
}

export interface AuthMetadata {
  termsVersion: string | null;
  privacyVersion: string | null;
  termsDocumentId: string | null;
  privacyDocumentId: string | null;
}

export interface LegalDocument {
  id: string;
  documentType: string;
  version: string;
  summary: string;
  body: string;
  locale: string;
}

export interface ProfileUpdateRequest {
  first_name?: string;
  last_name?: string;
  phone?: string;
  show_real_name?: boolean;
  show_phone_number?: boolean;
  show_email?: boolean;
  date_of_birth?: string | null;
  sex?: string | null;
  organization?: string | null;
  two_factor_enabled?: boolean;
}

interface AuthSessionResponse {
  access: string;
  refresh: string;
  user: Record<string, unknown>;
  requires_otp?: boolean;
}

export interface LoginOtpChallenge {
  requiresOtp: true;
  challengeId: string;
  emailHint: string;
}

export type LoginResult = AuthUser | LoginOtpChallenge;

@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly http = inject(HttpClient);
  private readonly storage = inject(TokenStorageService);
  private readonly locale = inject(LocaleService);

  private mapError(error: unknown) {
    return mapHttpError(error, {
      unexpected: this.locale.t('errors.unexpected'),
      requestFailed: this.locale.t('errors.requestFailed'),
      network: this.locale.t('errors.network'),
    });
  }

  private readonly userSignal = signal<AuthUser | null>(null);
  private readonly restoringSignal = signal(false);

  readonly currentUser = this.userSignal.asReadonly();
  readonly isAuthenticated = computed(() => this.userSignal() != null);
  readonly isRestoring = this.restoringSignal.asReadonly();

  private url(path: string): string {
    return `${environment.apiBaseUrl}${path}`;
  }

  async login(request: LoginRequest): Promise<LoginResult> {
    try {
      const data = await firstValueFrom(
        this.http.post<Record<string, unknown>>(this.url(ApiPaths.authLogin), {
          email: request.email,
          password: request.password,
        }),
      );
      if (data['requires_otp'] === true) {
        return {
          requiresOtp: true,
          challengeId:
            typeof data['challenge_id'] === 'string' ? data['challenge_id'] : '',
          emailHint: typeof data['email_hint'] === 'string' ? data['email_hint'] : request.email,
        };
      }
      return this.persistSession(data as unknown as AuthSessionResponse);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async verifyLoginOtp(challengeId: string, code: string): Promise<AuthUser> {
    try {
      const data = await firstValueFrom(
        this.http.post<AuthSessionResponse>(this.url(ApiPaths.authLoginVerifyOtp), {
          challenge_id: challengeId,
          code,
        }),
      );
      return this.persistSession(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async sendOtp(purpose: 'password_change' | 'login'): Promise<{ challengeId: string }> {
    try {
      const data = await firstValueFrom(
        this.http.post<Record<string, unknown>>(this.url(ApiPaths.authOtpSend), {
          purpose,
        }),
      );
      return {
        challengeId:
          typeof data['challenge_id'] === 'string' ? data['challenge_id'] : '',
      };
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async changePassword(payload: {
    currentPassword: string;
    newPassword: string;
    challengeId: string;
    code: string;
  }): Promise<void> {
    try {
      await firstValueFrom(
        this.http.post(this.url(ApiPaths.authPasswordChange), {
          current_password: payload.currentPassword,
          new_password: payload.newPassword,
          challenge_id: payload.challengeId,
          code: payload.code,
        }),
      );
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async requestPasswordReset(email: string): Promise<{ challengeId: string | null }> {
    try {
      const data = await firstValueFrom(
        this.http.post<Record<string, unknown>>(this.url(ApiPaths.authPasswordResetRequest), {
          email,
        }),
      );
      return {
        challengeId:
          typeof data['challenge_id'] === 'string' ? data['challenge_id'] : null,
      };
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async confirmPasswordReset(payload: {
    email: string;
    challengeId: string;
    code: string;
    newPassword: string;
  }): Promise<void> {
    try {
      await firstValueFrom(
        this.http.post(this.url(ApiPaths.authPasswordResetConfirm), {
          email: payload.email,
          challenge_id: payload.challengeId,
          code: payload.code,
          new_password: payload.newPassword,
        }),
      );
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async fetchMetadata(): Promise<AuthMetadata> {
    try {
      const data = await firstValueFrom(
        this.http.get<Record<string, unknown>>(this.url(ApiPaths.authMetadata)),
      );
      return {
        termsVersion:
          typeof data['terms_version'] === 'string' ? data['terms_version'] : null,
        privacyVersion:
          typeof data['privacy_version'] === 'string' ? data['privacy_version'] : null,
        termsDocumentId:
          data['terms_document_id'] != null ? String(data['terms_document_id']) : null,
        privacyDocumentId:
          data['privacy_document_id'] != null
            ? String(data['privacy_document_id'])
            : null,
      };
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async fetchLegalDocument(documentType: 'terms' | 'privacy'): Promise<LegalDocument> {
    try {
      const lang = this.locale.locale();
      const data = await firstValueFrom(
        this.http.get<Record<string, unknown>>(
          this.url(ApiPaths.legalDocument(documentType)),
          { params: { lang } },
        ),
      );
      return {
        id: data['id'] != null ? String(data['id']) : '',
        documentType:
          typeof data['document_type'] === 'string' ? data['document_type'] : documentType,
        version: typeof data['version'] === 'string' ? data['version'] : '',
        summary: typeof data['summary'] === 'string' ? data['summary'] : '',
        body: typeof data['body'] === 'string' ? data['body'] : '',
        locale: typeof data['locale'] === 'string' ? data['locale'] : lang,
      };
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async acceptLegal(termsVersion: string, privacyVersion: string): Promise<AuthUser> {
    try {
      const data = await firstValueFrom(
        this.http.post<Record<string, unknown>>(this.url(ApiPaths.authAcceptLegal), {
          accepted_terms_version: termsVersion,
          accepted_privacy_version: privacyVersion,
        }),
      );
      const user = parseAuthUser(data);
      this.storage.saveUser(user);
      this.userSignal.set(user);
      return user;
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async register(request: RegisterRequest): Promise<AuthUser> {
    try {
      const data = await firstValueFrom(
        this.http.post<AuthSessionResponse>(this.url(ApiPaths.authRegister), {
          email: request.email,
          username: request.username,
          password: request.password,
          password_confirm: request.passwordConfirm,
          first_name: request.firstName ?? '',
          last_name: request.lastName ?? '',
          phone: request.phone ?? '',
          role: request.role ?? 'CLIENT',
          accepted_terms_version: request.acceptedTermsVersion,
          accepted_privacy_version: request.acceptedPrivacyVersion,
        }),
      );
      return this.persistSession(data);
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async logout(): Promise<void> {
    const refresh = this.storage.getRefreshToken();
    try {
      if (refresh) {
        await firstValueFrom(
          this.http.post<void>(this.url(ApiPaths.authLogout), { refresh }),
        );
      }
    } catch {
      // Still clear local session
    } finally {
      this.storage.clearSession();
      this.userSignal.set(null);
    }
  }

  async fetchProfile(): Promise<AuthUser> {
    try {
      const data = await firstValueFrom(
        this.http.get<Record<string, unknown>>(this.url(ApiPaths.authProfile)),
      );
      const user = parseAuthUser(data);
      this.storage.saveUser(user);
      this.userSignal.set(user);
      return user;
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async updateProfile(payload: ProfileUpdateRequest): Promise<AuthUser> {
    try {
      const data = await firstValueFrom(
        this.http.put<Record<string, unknown>>(this.url(ApiPaths.authProfile), payload),
      );
      const user = parseAuthUser(data);
      this.storage.saveUser(user);
      this.userSignal.set(user);
      return user;
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async uploadAvatar(file: File): Promise<AuthUser> {
    const form = new FormData();
    form.append('avatar', file);
    try {
      const data = await firstValueFrom(
        this.http.post<Record<string, unknown>>(this.url(ApiPaths.authAvatar), form),
      );
      const user = parseAuthUser(data);
      this.storage.saveUser(user);
      this.userSignal.set(user);
      return user;
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async ensureTrustAlias(): Promise<string> {
    try {
      const data = await firstValueFrom(
        this.http.get<{ trust_alias: string }>(this.url(ApiPaths.authGenerateAlias)),
      );
      const alias = data.trust_alias;
      const current = this.userSignal();
      if (current && alias) {
        const updated = { ...current, trustAlias: alias };
        this.storage.saveUser(updated);
        this.userSignal.set(updated);
      }
      return alias;
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async regenerateTrustAlias(): Promise<string> {
    try {
      const data = await firstValueFrom(
        this.http.post<{ trust_alias: string }>(this.url(ApiPaths.authRegenerateAlias), {}),
      );
      const alias = data.trust_alias;
      const current = this.userSignal();
      if (current && alias) {
        const updated = { ...current, trustAlias: alias };
        this.storage.saveUser(updated);
        this.userSignal.set(updated);
      }
      return alias;
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async submitVerification(idDocument: File, selfieDocument: File): Promise<AuthUser> {
    const form = new FormData();
    form.append('id_document', idDocument);
    form.append('selfie_document', selfieDocument);
    try {
      await firstValueFrom(this.http.post<unknown>(this.url(ApiPaths.authVerify), form));
      return await this.fetchProfile();
    } catch (error) {
      throw this.mapError(error);
    }
  }

  async restoreSession(): Promise<AuthUser | null> {
    if (!this.storage.hasAccessToken()) {
      this.userSignal.set(null);
      return null;
    }

    this.restoringSignal.set(true);
    const cached = this.storage.loadUser();
    if (cached) {
      this.userSignal.set(cached);
    }

    try {
      const fresh = await this.fetchProfile();
      return fresh;
    } catch {
      return cached;
    } finally {
      this.restoringSignal.set(false);
    }
  }

  /** Used by the auth interceptor when refresh fails. */
  clearLocalSession(): void {
    this.storage.clearSession();
    this.userSignal.set(null);
  }

  private persistSession(data: AuthSessionResponse): AuthUser {
    if (!data.access || !data.refresh || !data.user) {
      throw {
        message: this.locale.t('auth.invalidResponse'),
        status: null,
        fieldErrors: {},
        code: 'AUTH_INVALID_RESPONSE',
      };
    }
    const user = parseAuthUser(data.user);
    this.storage.saveTokens(data.access, data.refresh);
    this.storage.saveUser(user);
    this.userSignal.set(user);
    return user;
  }
}
