/** Conditional staff row actions matching backend status gates. */

export interface StaffActionFlags {
  canApprove: boolean;
  canReject: boolean;
  canSuspend: boolean;
  canUnsuspend: boolean;
  canReview: boolean;
  canViewOnly: boolean;
}

export function staffUserActions(
  statusValue: string | number | null | undefined,
): StaffActionFlags {
  const status = statusValue == null ? '' : String(statusValue);
  const canApprove = status === 'P' || status === 'R';
  const canReject = status === 'P';
  return {
    canApprove,
    canReject,
    canSuspend: false,
    canUnsuspend: false,
    canReview: canApprove || canReject,
    canViewOnly: !canApprove && !canReject,
  };
}

export function staffOrgActions(
  statusValue: string | number | null | undefined,
): StaffActionFlags {
  const status = statusValue == null ? '' : String(statusValue);
  const canApprove = status === 'P' || status === 'R';
  const canReject = status === 'P';
  const canSuspend = status === 'V';
  const canUnsuspend = status === 'S';
  return {
    canApprove,
    canReject,
    canSuspend,
    canUnsuspend,
    canReview: canApprove || canReject,
    canViewOnly: !canApprove && !canReject && !canSuspend && !canUnsuspend,
  };
}
