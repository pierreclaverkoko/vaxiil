import { Injectable } from '@angular/core';

import { AuthUser, authUserToJson, parseAuthUser } from '@/models/auth-user';

const ACCESS_TOKEN_KEY = 'access_token';
const REFRESH_TOKEN_KEY = 'refresh_token';
const USER_PROFILE_KEY = 'user_profile';

@Injectable({ providedIn: 'root' })
export class TokenStorageService {
  getAccessToken(): string | null {
    return this.read(ACCESS_TOKEN_KEY);
  }

  getRefreshToken(): string | null {
    return this.read(REFRESH_TOKEN_KEY);
  }

  saveTokens(accessToken: string, refreshToken: string): void {
    localStorage.setItem(ACCESS_TOKEN_KEY, accessToken);
    localStorage.setItem(REFRESH_TOKEN_KEY, refreshToken);
  }

  clearTokens(): void {
    localStorage.removeItem(ACCESS_TOKEN_KEY);
    localStorage.removeItem(REFRESH_TOKEN_KEY);
  }

  hasAccessToken(): boolean {
    const token = this.getAccessToken();
    return token != null && token.length > 0;
  }

  saveUser(user: AuthUser): void {
    localStorage.setItem(USER_PROFILE_KEY, JSON.stringify(authUserToJson(user)));
  }

  loadUser(): AuthUser | null {
    const raw = localStorage.getItem(USER_PROFILE_KEY);
    if (!raw) {
      return null;
    }
    try {
      const parsed = JSON.parse(raw) as Record<string, unknown>;
      return parseAuthUser(parsed);
    } catch {
      return null;
    }
  }

  clearUser(): void {
    localStorage.removeItem(USER_PROFILE_KEY);
  }

  clearSession(): void {
    this.clearTokens();
    this.clearUser();
  }

  private read(key: string): string | null {
    const value = localStorage.getItem(key);
    return value && value.length > 0 ? value : null;
  }
}
