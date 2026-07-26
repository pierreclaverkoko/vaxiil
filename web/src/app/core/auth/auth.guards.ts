import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';

import { AuthService } from '@/core/auth/auth.service';
import { TokenStorageService } from '@/core/auth/token-storage.service';

/** Requires a stored access token (and optionally restored user). Preserves returnUrl. */
export const authGuard: CanActivateFn = async (route, state) => {
  const auth = inject(AuthService);
  const storage = inject(TokenStorageService);
  const router = inject(Router);

  if (auth.currentUser()) {
    return true;
  }
  if (!storage.hasAccessToken()) {
    return router.createUrlTree(['/login'], {
      queryParams: { returnUrl: state.url },
    });
  }
  const user = await auth.restoreSession();
  if (user) {
    return true;
  }
  return router.createUrlTree(['/login'], {
    queryParams: { returnUrl: state.url },
  });
};

/** Redirects authenticated users away from login/register/onboarding. */
export const guestGuard: CanActivateFn = async () => {
  const auth = inject(AuthService);
  const storage = inject(TokenStorageService);
  const router = inject(Router);

  if (auth.currentUser()) {
    return router.createUrlTree(['/discover']);
  }
  if (storage.hasAccessToken()) {
    const user = await auth.restoreSession();
    if (user) {
      return router.createUrlTree(['/discover']);
    }
  }
  return true;
};

/**
 * If the user is authenticated and has not verified their email,
 * redirect to the blocking verification page (before legal acceptance).
 */
export const emailVerificationGuard: CanActivateFn = async (_route, state) => {
  const auth = inject(AuthService);
  const storage = inject(TokenStorageService);
  const router = inject(Router);

  if (state.url.startsWith('/email-verification')) {
    return true;
  }

  let user = auth.currentUser();
  if (!user && storage.hasAccessToken()) {
    user = await auth.restoreSession();
  }
  if (!user) {
    return true;
  }
  if (user.needsEmailVerification) {
    return router.createUrlTree(['/email-verification'], {
      queryParams: { returnUrl: state.url },
    });
  }
  return true;
};

/**
 * If the user is authenticated and has not accepted the current legal versions,
 * redirect to the blocking acceptance page.
 */
export const legalAcceptanceGuard: CanActivateFn = async (_route, state) => {
  const auth = inject(AuthService);
  const storage = inject(TokenStorageService);
  const router = inject(Router);

  if (state.url.startsWith('/legal-acceptance') || state.url.startsWith('/email-verification')) {
    return true;
  }

  let user = auth.currentUser();
  if (!user && storage.hasAccessToken()) {
    user = await auth.restoreSession();
  }
  if (!user) {
    return true;
  }
  if (user.needsEmailVerification) {
    return true;
  }
  if (user.legal?.needsAcceptance) {
    return router.createUrlTree(['/legal-acceptance'], {
      queryParams: { returnUrl: state.url },
    });
  }
  return true;
};

/** Requires authenticated platform staff (`is_staff`). */
export const staffGuard: CanActivateFn = async (route, state) => {
  const auth = inject(AuthService);
  const storage = inject(TokenStorageService);
  const router = inject(Router);

  let user = auth.currentUser();
  if (!user && storage.hasAccessToken()) {
    user = await auth.restoreSession();
  }
  if (!user) {
    return router.createUrlTree(['/login'], {
      queryParams: { returnUrl: state.url },
    });
  }
  if (!user.isStaff) {
    return router.createUrlTree(['/discover']);
  }
  return true;
};
