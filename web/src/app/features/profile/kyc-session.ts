/** Session flag: user submitted KYC docs this browser session (backend has no "docs on file" flag). */
const KYC_SUBMITTED_KEY = 'vaxiil_kyc_submitted';

export function markKycSubmitted(): void {
  try {
    sessionStorage.setItem(KYC_SUBMITTED_KEY, '1');
  } catch {
    /* ignore quota / private mode */
  }
}

export function clearKycSubmitted(): void {
  try {
    sessionStorage.removeItem(KYC_SUBMITTED_KEY);
  } catch {
    /* ignore */
  }
}

export function wasKycSubmittedThisSession(): boolean {
  try {
    return sessionStorage.getItem(KYC_SUBMITTED_KEY) === '1';
  } catch {
    return false;
  }
}

export type KycUiState = 'verified' | 'rejected' | 'in_review' | 'not_verified';

export function resolveKycUiState(
  statusValue: string | number | undefined | null,
  submittedThisSession = wasKycSubmittedThisSession(),
): KycUiState {
  const code = statusValue != null ? String(statusValue) : '';
  if (code === 'V') {
    return 'verified';
  }
  if (code === 'R') {
    return 'rejected';
  }
  if (code === 'P' && submittedThisSession) {
    return 'in_review';
  }
  return 'not_verified';
}
