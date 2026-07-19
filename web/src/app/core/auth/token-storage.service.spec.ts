import { TestBed } from '@angular/core/testing';

import { parseAuthUser } from '@/models/auth-user';
import { TokenStorageService } from './token-storage.service';

describe('TokenStorageService', () => {
  let storage: TokenStorageService;

  beforeEach(() => {
    localStorage.clear();
    TestBed.configureTestingModule({});
    storage = TestBed.inject(TokenStorageService);
  });

  afterEach(() => {
    localStorage.clear();
  });

  it('saves and reads tokens', () => {
    storage.saveTokens('access', 'refresh');
    expect(storage.getAccessToken()).toBe('access');
    expect(storage.getRefreshToken()).toBe('refresh');
    expect(storage.hasAccessToken()).toBe(true);
  });

  it('persists user profile json', () => {
    const user = parseAuthUser({
      id: '1',
      email: 'a@b.com',
      first_name: 'Ada',
      last_name: 'Lovelace',
    });
    storage.saveUser(user);
    expect(storage.loadUser()?.email).toBe('a@b.com');
    expect(storage.loadUser()?.firstName).toBe('Ada');
  });

  it('clears session', () => {
    storage.saveTokens('a', 'r');
    storage.saveUser(parseAuthUser({ id: '1', email: 'a@b.com' }));
    storage.clearSession();
    expect(storage.hasAccessToken()).toBe(false);
    expect(storage.loadUser()).toBeNull();
  });
});
