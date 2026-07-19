import { Routes } from '@angular/router';

import {
  authGuard,
  guestGuard,
  legalAcceptanceGuard,
  staffGuard,
} from '@/core/auth/auth.guards';

export const routes: Routes = [
  {
    path: '',
    loadComponent: () =>
      import('./shells/public-shell/public-shell').then((m) => m.PublicShellComponent),
    children: [
      { path: '', pathMatch: 'full', redirectTo: 'onboarding' },
      {
        path: 'onboarding',
        canActivate: [guestGuard],
        loadComponent: () =>
          import('./features/auth/onboarding-page/onboarding-page').then(
            (m) => m.OnboardingPageComponent,
          ),
      },
      {
        path: 'login',
        canActivate: [guestGuard],
        loadComponent: () =>
          import('./features/auth/login-page/login-page').then((m) => m.LoginPageComponent),
      },
      {
        path: 'forgot-password',
        canActivate: [guestGuard],
        loadComponent: () =>
          import('./features/auth/forgot-password-page/forgot-password-page').then(
            (m) => m.ForgotPasswordPageComponent,
          ),
      },
      {
        path: 'register',
        canActivate: [guestGuard],
        loadComponent: () =>
          import('./features/auth/register-page/register-page').then(
            (m) => m.RegisterPageComponent,
          ),
      },
      {
        path: 'terms',
        loadComponent: () =>
          import('./features/auth/legal-page/legal-page').then((m) => m.LegalPageComponent),
        data: {
          legalType: 'terms',
        },
      },
      {
        path: 'privacy',
        loadComponent: () =>
          import('./features/auth/legal-page/legal-page').then((m) => m.LegalPageComponent),
        data: {
          legalType: 'privacy',
        },
      },
    ],
  },
  {
    path: 'legal-acceptance',
    canActivate: [authGuard],
    loadComponent: () =>
      import('./features/auth/legal-acceptance-page/legal-acceptance-page').then(
        (m) => m.LegalAcceptancePageComponent,
      ),
  },
  {
    path: '',
    canActivate: [legalAcceptanceGuard],
    loadComponent: () =>
      import('./shells/consumer-app-shell/consumer-app-shell').then(
        (m) => m.ConsumerAppShellComponent,
      ),
    children: [
      {
        path: 'discover',
        loadComponent: () =>
          import('./features/discover/discover-page/discover-page').then(
            (m) => m.DiscoverPageComponent,
          ),
      },
      {
        path: 'services',
        loadComponent: () =>
          import('./features/services/services-list-page/services-list-page').then(
            (m) => m.ServicesListPageComponent,
          ),
      },
      {
        path: 'services/:id',
        loadComponent: () =>
          import('./shared/ui/adaptive-modal/adaptive-modal-host').then(
            (m) => m.AdaptiveModalHostComponent,
          ),
        children: [
          {
            path: '',
            loadComponent: () =>
              import('./features/services/service-detail-page/service-detail-page').then(
                (m) => m.ServiceDetailPageComponent,
              ),
          },
        ],
      },
      {
        path: 'services/:id/book',
        canActivate: [authGuard],
        loadComponent: () =>
          import('./shared/ui/adaptive-modal/adaptive-modal-host').then(
            (m) => m.AdaptiveModalHostComponent,
          ),
        children: [
          {
            path: '',
            loadComponent: () =>
              import('./features/bookings/booking-schedule-page/booking-schedule-page').then(
                (m) => m.BookingSchedulePageComponent,
              ),
          },
        ],
      },
      {
        path: 'bookings',
        canActivate: [authGuard],
        loadComponent: () =>
          import('./features/bookings/bookings-list-page/bookings-list-page').then(
            (m) => m.BookingsListPageComponent,
          ),
      },
      {
        path: 'bookings/:id/confirmation',
        canActivate: [authGuard],
        data: { dismissUrl: '/bookings' },
        loadComponent: () =>
          import('./shared/ui/adaptive-modal/adaptive-modal-host').then(
            (m) => m.AdaptiveModalHostComponent,
          ),
        children: [
          {
            path: '',
            loadComponent: () =>
              import('./features/bookings/booking-confirmation-page/booking-confirmation-page').then(
                (m) => m.BookingConfirmationPageComponent,
              ),
          },
        ],
      },
      {
        path: 'bookings/:id/pay',
        canActivate: [authGuard],
        data: { dismissUrl: '/bookings/:id' },
        loadComponent: () =>
          import('./shared/ui/adaptive-modal/adaptive-modal-host').then(
            (m) => m.AdaptiveModalHostComponent,
          ),
        children: [
          {
            path: '',
            loadComponent: () =>
              import('./features/bookings/payment-confirm-page/payment-confirm-page').then(
                (m) => m.PaymentConfirmPageComponent,
              ),
          },
        ],
      },
      {
        path: 'bookings/:id',
        canActivate: [authGuard],
        data: { dismissUrl: '/bookings' },
        loadComponent: () =>
          import('./shared/ui/adaptive-modal/adaptive-modal-host').then(
            (m) => m.AdaptiveModalHostComponent,
          ),
        children: [
          {
            path: '',
            loadComponent: () =>
              import('./features/bookings/booking-detail-page/booking-detail-page').then(
                (m) => m.BookingDetailPageComponent,
              ),
          },
        ],
      },
      {
        path: 'payment-return',
        canActivate: [authGuard],
        data: { dismissUrl: '/bookings' },
        loadComponent: () =>
          import('./shared/ui/adaptive-modal/adaptive-modal-host').then(
            (m) => m.AdaptiveModalHostComponent,
          ),
        children: [
          {
            path: '',
            loadComponent: () =>
              import('./features/bookings/payment-return-page/payment-return-page').then(
                (m) => m.PaymentReturnPageComponent,
              ),
          },
        ],
      },
      {
        path: 'profile',
        canActivate: [authGuard],
        loadComponent: () =>
          import('./features/profile/profile-page/profile-page').then(
            (m) => m.ProfilePageComponent,
          ),
      },
      {
        path: 'profile/verify',
        canActivate: [authGuard],
        loadComponent: () =>
          import('./shared/ui/adaptive-modal/adaptive-modal-host').then(
            (m) => m.AdaptiveModalHostComponent,
          ),
        children: [
          {
            path: '',
            loadComponent: () =>
              import('./features/profile/kyc-verify-page/kyc-verify-page').then(
                (m) => m.KycVerifyPageComponent,
              ),
          },
        ],
      },
      {
        path: 'profile/personal',
        canActivate: [authGuard],
        data: { dismissUrl: '/profile' },
        loadComponent: () =>
          import('./shared/ui/adaptive-modal/adaptive-modal-host').then(
            (m) => m.AdaptiveModalHostComponent,
          ),
        children: [
          {
            path: '',
            loadComponent: () =>
              import('./features/profile/personal-info-page/personal-info-page').then(
                (m) => m.PersonalInfoPageComponent,
              ),
          },
        ],
      },
      {
        path: 'profile/security',
        canActivate: [authGuard],
        data: { dismissUrl: '/profile' },
        loadComponent: () =>
          import('./shared/ui/adaptive-modal/adaptive-modal-host').then(
            (m) => m.AdaptiveModalHostComponent,
          ),
        children: [
          {
            path: '',
            loadComponent: () =>
              import('./features/profile/security-page/security-page').then(
                (m) => m.SecurityPageComponent,
              ),
          },
        ],
      },
      {
        path: 'profile/notifications',
        canActivate: [authGuard],
        loadComponent: () =>
          import('./shared/ui/adaptive-modal/adaptive-modal-host').then(
            (m) => m.AdaptiveModalHostComponent,
          ),
        children: [
          {
            path: '',
            loadComponent: () =>
              import('./features/profile/profile-stub-page/profile-stub-page').then(
                (m) => m.ProfileStubPageComponent,
              ),
            data: {
              titleKey: 'profile.notifications',
              bodyKey: 'profile.notificationsBody',
            },
          },
        ],
      },
      {
        path: 'profile/about',
        canActivate: [authGuard],
        loadComponent: () =>
          import('./shared/ui/adaptive-modal/adaptive-modal-host').then(
            (m) => m.AdaptiveModalHostComponent,
          ),
        children: [
          {
            path: '',
            loadComponent: () =>
              import('./features/profile/profile-stub-page/profile-stub-page').then(
                (m) => m.ProfileStubPageComponent,
              ),
            data: {
              titleKey: 'profile.about',
              bodyKey: 'profile.aboutBody',
              showContact: true,
            },
          },
        ],
      },
      {
        path: 'profile/terms',
        canActivate: [authGuard],
        loadComponent: () =>
          import('./shared/ui/adaptive-modal/adaptive-modal-host').then(
            (m) => m.AdaptiveModalHostComponent,
          ),
        children: [
          {
            path: '',
            loadComponent: () =>
              import('./features/profile/profile-legal-page/profile-legal-page').then(
                (m) => m.ProfileLegalPageComponent,
              ),
            data: {
              legalType: 'terms',
            },
          },
        ],
      },
      {
        path: 'profile/privacy',
        canActivate: [authGuard],
        loadComponent: () =>
          import('./shared/ui/adaptive-modal/adaptive-modal-host').then(
            (m) => m.AdaptiveModalHostComponent,
          ),
        children: [
          {
            path: '',
            loadComponent: () =>
              import('./features/profile/profile-legal-page/profile-legal-page').then(
                (m) => m.ProfileLegalPageComponent,
              ),
            data: {
              legalType: 'privacy',
            },
          },
        ],
      },
    ],
  },
  {
    path: 'business',
    canActivate: [authGuard, legalAcceptanceGuard],
    loadComponent: () =>
      import('./shells/business-manage-shell/business-manage-shell').then(
        (m) => m.BusinessManageShellComponent,
      ),
    children: [
      {
        path: '',
        loadComponent: () =>
          import('./features/business/business-list-page/business-list-page').then(
            (m) => m.BusinessListPageComponent,
          ),
      },
      {
        path: 'setup',
        loadComponent: () =>
          import('./shared/ui/adaptive-modal/adaptive-modal-host').then(
            (m) => m.AdaptiveModalHostComponent,
          ),
        children: [
          {
            path: '',
            loadComponent: () =>
              import('./features/business/business-setup-page/business-setup-page').then(
                (m) => m.BusinessSetupPageComponent,
              ),
          },
        ],
      },
      {
        path: ':orgId',
        loadComponent: () =>
          import('./features/business/business-hub-page/business-hub-page').then(
            (m) => m.BusinessHubPageComponent,
          ),
      },
      {
        path: ':orgId/settings',
        loadComponent: () =>
          import('./features/business/business-settings-page/business-settings-page').then(
            (m) => m.BusinessSettingsPageComponent,
          ),
      },
      {
        path: ':orgId/services',
        loadComponent: () =>
          import('./features/business/business-services-page/business-services-page').then(
            (m) => m.BusinessServicesPageComponent,
          ),
      },
      {
        path: ':orgId/services/new',
        loadComponent: () =>
          import('./shared/ui/adaptive-modal/adaptive-modal-host').then(
            (m) => m.AdaptiveModalHostComponent,
          ),
        children: [
          {
            path: '',
            loadComponent: () =>
              import('./features/business/business-service-edit-page/business-service-edit-page').then(
                (m) => m.BusinessServiceEditPageComponent,
              ),
          },
        ],
      },
      {
        path: ':orgId/services/:serviceId',
        loadComponent: () =>
          import('./shared/ui/adaptive-modal/adaptive-modal-host').then(
            (m) => m.AdaptiveModalHostComponent,
          ),
        children: [
          {
            path: '',
            loadComponent: () =>
              import('./features/business/business-service-edit-page/business-service-edit-page').then(
                (m) => m.BusinessServiceEditPageComponent,
              ),
          },
        ],
      },
      {
        path: ':orgId/bookings',
        loadComponent: () =>
          import('./features/business/business-bookings-page/business-bookings-page').then(
            (m) => m.BusinessBookingsPageComponent,
          ),
      },
      {
        path: ':orgId/bookings/:id',
        loadComponent: () =>
          import('./shared/ui/adaptive-modal/adaptive-modal-host').then(
            (m) => m.AdaptiveModalHostComponent,
          ),
        children: [
          {
            path: '',
            loadComponent: () =>
              import('./features/business/business-booking-detail-page/business-booking-detail-page').then(
                (m) => m.BusinessBookingDetailPageComponent,
              ),
          },
        ],
      },
      {
        path: ':orgId/team',
        loadComponent: () =>
          import('./features/business/business-team-page/business-team-page').then(
            (m) => m.BusinessTeamPageComponent,
          ),
      },
      {
        path: ':orgId/analytics',
        loadComponent: () =>
          import('./features/business/business-analytics-page/business-analytics-page').then(
            (m) => m.BusinessAnalyticsPageComponent,
          ),
      },
    ],
  },
  {
    path: 'staff',
    canActivate: [authGuard, legalAcceptanceGuard, staffGuard],
    loadComponent: () =>
      import('./shells/platform-staff-shell/platform-staff-shell').then(
        (m) => m.PlatformStaffShellComponent,
      ),
    children: [
      {
        path: '',
        loadComponent: () =>
          import('./features/staff/staff-home-page/staff-home-page').then(
            (m) => m.StaffHomePageComponent,
          ),
      },
      {
        path: 'users',
        loadComponent: () =>
          import('./features/staff/staff-users-page/staff-users-page').then(
            (m) => m.StaffUsersPageComponent,
          ),
      },
      {
        path: 'organizations',
        loadComponent: () =>
          import('./features/staff/staff-organizations-page/staff-organizations-page').then(
            (m) => m.StaffOrganizationsPageComponent,
          ),
      },
      {
        path: 'taxonomy',
        loadComponent: () =>
          import('./features/staff/staff-taxonomy-page/staff-taxonomy-page').then(
            (m) => m.StaffTaxonomyPageComponent,
          ),
      },
      {
        path: 'bookings',
        loadComponent: () =>
          import('./features/staff/staff-bookings-page/staff-bookings-page').then(
            (m) => m.StaffBookingsPageComponent,
          ),
      },
      {
        path: 'payments',
        loadComponent: () =>
          import('./features/staff/staff-payments-page/staff-payments-page').then(
            (m) => m.StaffPaymentsPageComponent,
          ),
      },
      {
        path: 'fees',
        loadComponent: () =>
          import('./features/staff/staff-fees-page/staff-fees-page').then(
            (m) => m.StaffFeesPageComponent,
          ),
      },
    ],
  },
  { path: '**', redirectTo: 'onboarding' },
];
