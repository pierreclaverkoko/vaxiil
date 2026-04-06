import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_state.dart';
import 'package:vaxiil_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:vaxiil_mobile/features/auth/presentation/pages/register_page.dart';
import 'package:vaxiil_mobile/features/auth/presentation/pages/splash_page.dart';
import 'package:vaxiil_mobile/features/bookings/presentation/pages/booking_confirmation_page.dart';
import 'package:vaxiil_mobile/features/bookings/presentation/pages/booking_detail_page.dart';
import 'package:vaxiil_mobile/features/bookings/presentation/pages/bookings_page.dart';
import 'package:vaxiil_mobile/features/bookings/presentation/pages/service_booking_page.dart';
import 'package:vaxiil_mobile/features/business/presentation/pages/business_analytics_page.dart';
import 'package:vaxiil_mobile/features/business/presentation/pages/business_bookings_page.dart';
import 'package:vaxiil_mobile/features/business/presentation/pages/business_list_page.dart';
import 'package:vaxiil_mobile/features/business/presentation/pages/business_profile_page.dart';
import 'package:vaxiil_mobile/features/business/presentation/pages/business_settings_page.dart';
import 'package:vaxiil_mobile/features/business/presentation/pages/business_service_edit_page.dart';
import 'package:vaxiil_mobile/features/business/presentation/pages/business_services_page.dart';
import 'package:vaxiil_mobile/features/business/presentation/pages/business_setup_page.dart';
import 'package:vaxiil_mobile/features/business/presentation/pages/business_team_page.dart';
import 'package:vaxiil_mobile/features/home/presentation/pages/home_page.dart';
import 'package:vaxiil_mobile/features/messages/presentation/pages/messages_page.dart';
import 'package:vaxiil_mobile/features/profile/presentation/pages/about_page.dart';
import 'package:vaxiil_mobile/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:vaxiil_mobile/features/profile/presentation/pages/identity_verification_page.dart';
import 'package:vaxiil_mobile/features/profile/presentation/pages/legal_pages.dart';
import 'package:vaxiil_mobile/features/profile/presentation/pages/privacy_settings_page.dart';
import 'package:vaxiil_mobile/features/profile/presentation/pages/profile_page.dart';
import 'package:vaxiil_mobile/features/profile/presentation/pages/theme_settings_page.dart';
import 'package:vaxiil_mobile/features/services/presentation/pages/service_detail_page.dart';
import 'package:vaxiil_mobile/features/services/presentation/pages/services_page.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_main_shell.dart';

class AppRouter {
  AppRouter._();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Prefer [buildVaxiilRouter] from tests and tooling if static resolution fails.
  static GoRouter createRouter(Listenable refreshListenable, AuthCubit authCubit) {
    return buildVaxiilRouter(refreshListenable, authCubit);
  }
}

/// Root [GoRouter] for the app (also used by [AppRouter.createRouter]).
GoRouter buildVaxiilRouter(Listenable refreshListenable, AuthCubit authCubit) {
  return GoRouter(
      navigatorKey: AppRouter.navigatorKey,
      refreshListenable: refreshListenable,
      initialLocation: AppRoutes.splash,
      debugLogDiagnostics: true,
      redirect: (context, state) {
        final status = authCubit.state.status;
        final loc = state.matchedLocation;
        final atLogin = loc == AppRoutes.login;
        final atRegister = loc == AppRoutes.register;
        final atSplash = loc == AppRoutes.splash;
        final atOnboarding = loc == AppRoutes.onboarding;
        final atPublicInfo = loc == AppRoutes.about ||
            loc == AppRoutes.theme ||
            loc == AppRoutes.terms ||
            loc == AppRoutes.privacy;

        if (status == AuthStatus.unknown) {
          if (atSplash || atOnboarding) return null;
          return AppRoutes.splash;
        }
        if (status == AuthStatus.unauthenticated) {
          // Allow onboarding / splash until the user taps Skip or Get Started.
          if (atSplash || atOnboarding) return null;
          if (atLogin || atRegister || atPublicInfo) return null;
          return AppRoutes.login;
        }
        if (status == AuthStatus.authenticated) {
          // Splash / onboarding requires an explicit Get Started (or Skip); do not
          // redirect as soon as the session restores.
          if (atSplash || atOnboarding) return null;
          if (atLogin || atRegister) {
            return AppRoutes.home;
          }
          return null;
        }
        return null;
      },
      routes: [
        GoRoute(
          path: AppRoutes.splash,
          name: 'splash',
          builder: (context, state) => const SplashPage(),
        ),
        GoRoute(
          path: AppRoutes.onboarding,
          name: 'onboarding',
          builder: (context, state) => const SplashPage(),
        ),
        GoRoute(
          path: AppRoutes.login,
          name: 'login',
          builder: (context, state) => const LoginPage(),
        ),
        GoRoute(
          path: AppRoutes.register,
          name: 'register',
          builder: (context, state) => const RegisterPage(),
        ),
        GoRoute(
          path: AppRoutes.about,
          name: 'about',
          builder: (context, state) => const AboutPage(),
        ),
        GoRoute(
          path: AppRoutes.theme,
          name: 'theme',
          builder: (context, state) => const ThemeSettingsPage(),
        ),
        GoRoute(
          path: AppRoutes.terms,
          name: 'terms',
          builder: (context, state) => const TermsOfServicePage(),
        ),
        GoRoute(
          path: AppRoutes.privacy,
          name: 'privacy',
          builder: (context, state) => const PrivacyPolicyPage(),
        ),
        GoRoute(
          path: AppRoutes.forgotPassword,
          name: 'forgot_password',
          builder: (context, state) => const Placeholder(),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return VaxiilMainShell(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.home,
                  name: 'home',
                  builder: (context, state) => const HomePage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.bookings,
                  name: 'bookings',
                  builder: (context, state) => const BookingsPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.messages,
                  name: 'messages',
                  builder: (context, state) => const MessagesPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.profile,
                  name: 'profile',
                  builder: (context, state) => const ProfilePage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.services,
                  name: 'services',
                  builder: (context, state) {
                    final extra = state.extra;
                    final Widget page;
                    if (extra is Map) {
                      page = ServicesPage(
                        initialSearchQuery: extra['search'] as String?,
                        initialCategoryId: extra['categoryId'] as String?,
                      );
                    } else if (extra is String) {
                      page = ServicesPage(initialSearchQuery: extra);
                    } else {
                      page = const ServicesPage();
                    }
                    return page;
                  },
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.business,
                  name: 'business',
                  builder: (context, state) => const BusinessListPage(),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.serviceDetails,
          name: 'service_details',
          builder: (context, state) {
            final id = state.uri.queryParameters['id'] ?? '';
            return ServiceDetailPage(serviceId: id);
          },
        ),
        GoRoute(
          path: AppRoutes.serviceBooking,
          name: 'service_booking',
          builder: (context, state) {
            final id = state.uri.queryParameters['id'] ?? '';
            final variantId = state.uri.queryParameters['variantId'];
            return ServiceBookingPage(
              serviceId: id,
              variantId: variantId,
            );
          },
        ),
        GoRoute(
          path: AppRoutes.bookingDetails,
          name: 'booking_details',
          builder: (context, state) {
            final id = state.uri.queryParameters['id'] ?? '';
            return BookingDetailPage(bookingId: id);
          },
        ),
        GoRoute(
          path: AppRoutes.bookingConfirmation,
          name: 'booking_confirmation',
          builder: (context, state) {
            final id = state.uri.queryParameters['id'] ?? '';
            return BookingConfirmationPage(bookingId: id);
          },
        ),
        GoRoute(
          path: AppRoutes.businessList,
          name: 'business_list',
          redirect: (context, state) => AppRoutes.business,
        ),
        GoRoute(
          path: AppRoutes.businessSetup,
          name: 'business_setup',
          builder: (context, state) => const BusinessSetupPage(),
        ),
        GoRoute(
          path: AppRoutes.businessProfile,
          name: 'business_profile',
          builder: (context, state) {
            final id = state.uri.queryParameters['id'];
            return BusinessProfilePage(organizationId: id);
          },
        ),
        GoRoute(
          path: AppRoutes.businessServices,
          name: 'business_services',
          builder: (context, state) {
            final id = state.uri.queryParameters['id'] ?? '';
            return BusinessServicesPage(organizationId: id);
          },
        ),
        GoRoute(
          path: AppRoutes.businessServiceEdit,
          name: 'business_service_edit',
          builder: (context, state) {
            final id = state.uri.queryParameters['id'] ?? '';
            final serviceId = state.uri.queryParameters['serviceId'];
            return BusinessServiceEditPage(
              organizationId: id,
              serviceId: serviceId,
            );
          },
        ),
        GoRoute(
          path: AppRoutes.editProfile,
          name: 'edit_profile',
          builder: (context, state) => const EditProfilePage(),
        ),
        GoRoute(
          path: AppRoutes.privacySettings,
          name: 'privacy_settings',
          builder: (context, state) => const PrivacySettingsPage(),
        ),
        GoRoute(
          path: AppRoutes.identityVerification,
          name: 'identity_verification',
          builder: (context, state) => const IdentityVerificationPage(),
        ),
        GoRoute(
          path: AppRoutes.businessPractitioners,
          name: 'business_practitioners',
          builder: (context, state) {
            final id = state.uri.queryParameters['id'] ?? '';
            return BusinessTeamPage(organizationId: id);
          },
        ),
        GoRoute(
          path: AppRoutes.businessAnalytics,
          name: 'business_analytics',
          builder: (context, state) {
            final id = state.uri.queryParameters['id'] ?? '';
            return BusinessAnalyticsPage(organizationId: id);
          },
        ),
        GoRoute(
          path: AppRoutes.businessBookings,
          name: 'business_bookings',
          builder: (context, state) {
            final id = state.uri.queryParameters['id'] ?? '';
            return BusinessBookingsPage(organizationId: id);
          },
        ),
        GoRoute(
          path: AppRoutes.businessSettings,
          name: 'business_settings',
          builder: (context, state) {
            final id = state.uri.queryParameters['id'] ?? '';
            return BusinessSettingsPage(organizationId: id);
          },
        ),
        GoRoute(
          path: AppRoutes.paymentMethods,
          name: 'payment_methods',
          builder: (context, state) => const Placeholder(),
        ),
        GoRoute(
          path: AppRoutes.favorites,
          name: 'favorites',
          builder: (context, state) => const Placeholder(),
        ),
        GoRoute(
          path: AppRoutes.settings,
          name: 'settings',
          builder: (context, state) => const Placeholder(),
        ),
        GoRoute(
          path: AppRoutes.language,
          name: 'language',
          builder: (context, state) => const Placeholder(),
        ),
        GoRoute(
          path: AppRoutes.notFound,
          name: 'not_found',
          builder: (context, state) => const NotFoundPage(),
        ),
        GoRoute(
          path: AppRoutes.serverError,
          name: 'server_error',
          builder: (context, state) => const ServerErrorPage(),
        ),
        GoRoute(
          path: AppRoutes.networkError,
          name: 'network_error',
          builder: (context, state) => const NetworkErrorPage(),
        ),
      ],
      errorBuilder: (context, state) => NotFoundPage(error: state.error?.toString()),
    );
}

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key, this.error});
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const HeroIcon(
              HeroIcons.exclamationTriangle,
              size: 64,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Page not found',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}

class ServerErrorPage extends StatelessWidget {
  const ServerErrorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Server Error')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const HeroIcon(
              HeroIcons.exclamationCircle,
              size: 64,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 16),
            const Text(
              'Server error occurred',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}

class NetworkErrorPage extends StatelessWidget {
  const NetworkErrorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Network Error')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const HeroIcon(
              HeroIcons.wifi,
              size: 64,
              color: AppTheme.warningColor,
            ),
            const SizedBox(height: 16),
            const Text(
              'Network error',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
