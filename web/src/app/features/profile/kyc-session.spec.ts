import { afterEach, describe, expect, it } from 'vitest';

import {
  clearKycSubmitted,
  markKycSubmitted,
  resolveKycUiState,
  wasKycSubmittedThisSession,
} from './kyc-session';

describe('kyc-session', () => {
  afterEach(() => {
    clearKycSubmitted();
  });

  it('resolveKycUiState maps verification values', () => {
    expect(resolveKycUiState('V')).toBe('verified');
    expect(resolveKycUiState('R')).toBe('rejected');
    expect(resolveKycUiState('P', false)).toBe('not_verified');
    expect(resolveKycUiState('P', true)).toBe('in_review');
    expect(resolveKycUiState(null)).toBe('not_verified');
  });

  it('tracks submit flag in sessionStorage', () => {
    expect(wasKycSubmittedThisSession()).toBe(false);
    markKycSubmitted();
    expect(wasKycSubmittedThisSession()).toBe(true);
    clearKycSubmitted();
    expect(wasKycSubmittedThisSession()).toBe(false);
  });
});
