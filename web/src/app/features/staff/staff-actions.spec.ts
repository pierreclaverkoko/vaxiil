import { describe, expect, it } from 'vitest';

import { staffOrgActions, staffUserActions } from './staff-actions';

describe('staffUserActions', () => {
  it('allows approve and reject for pending', () => {
    expect(staffUserActions('P')).toEqual({
      canApprove: true,
      canReject: true,
      canSuspend: false,
      canUnsuspend: false,
      canReview: true,
      canViewOnly: false,
    });
  });

  it('allows re-approve for rejected only', () => {
    const flags = staffUserActions('R');
    expect(flags.canApprove).toBe(true);
    expect(flags.canReject).toBe(false);
    expect(flags.canReview).toBe(true);
  });

  it('is view-only for verified', () => {
    expect(staffUserActions('V').canViewOnly).toBe(true);
    expect(staffUserActions('V').canReview).toBe(false);
  });
});

describe('staffOrgActions', () => {
  it('allows review for pending', () => {
    const flags = staffOrgActions('P');
    expect(flags.canApprove).toBe(true);
    expect(flags.canReject).toBe(true);
    expect(flags.canSuspend).toBe(false);
  });

  it('allows suspend only when verified', () => {
    const flags = staffOrgActions('V');
    expect(flags.canSuspend).toBe(true);
    expect(flags.canApprove).toBe(false);
    expect(flags.canReject).toBe(false);
    expect(flags.canReview).toBe(false);
  });

  it('allows unsuspend when suspended', () => {
    const flags = staffOrgActions('S');
    expect(flags.canUnsuspend).toBe(true);
    expect(flags.canSuspend).toBe(false);
  });
});
