import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/features/auth/presentation/pages/splash_page.dart';
import 'package:vaxiil_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:vaxiil_mobile/features/auth/presentation/pages/register_page.dart';
import 'package:vaxiil_mobile/features/home/presentation/pages/home_page.dart';
import 'package:vaxiil_mobile/features/services/presentation/pages/services_page.dart';
import 'package:vaxiil_mobile/features/bookings/presentation/pages/bookings_page.dart';
import 'package:vaxiil_mobile/features/profile/presentation/pages/profile_page.dart';
import 'package:vaxiil_mobile/features/business/presentation/pages/business_page.dart';
import 'package:vaxiil_mobile/core/bloc/base_bloc.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  static GoRouter get router {
    return GoRouter(
      navigatorKey: navigatorKey,
      initialLocation: AppRoutes.splash,
      debugLogDiagnostics: true,
      redirect: (context, state) {
        // Add authentication redirect logic here
        return null;
      },
      routes: [
        // Splash & Onboarding
        GoRoute(
          path: AppRoutes.splash,
          name: 'splash',
          builder: (context, state) => const SplashPage(),
        ),
        GoRoute(
          path: AppRoutes.onboarding,
          name: 'onboarding',
          builder: (context, state) => const Placeholder(), // TODO: Create onboarding page
        ),
        
        // Authentication
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
          path: AppRoutes.forgotPassword,
          name: 'forgot_password',
          builder: (context, state) => const Placeholder(), // TODO: Create forgot password page
        ),
        
        // Main Navigation (Bottom Navigation)
        ShellRoute(
          builder: (context, state, child) {
            return MainNavigation(child: child);
          },
          routes: [
            GoRoute(
              path: AppRoutes.home,
              name: 'home',
              builder: (context, state) => const HomePage(),
            ),
            GoRoute(
              path: AppRoutes.services,
              name: 'services',
              builder: (context, state) => const ServicesPage(),
            ),
            GoRoute(
              path: AppRoutes.bookings,
              name: 'bookings',
              builder: (context, state) => const BookingsPage(),
            ),
            GoRoute(
              path: AppRoutes.profile,
              name: 'profile',
              builder: (context, state) => const ProfilePage(),
            ),
            GoRoute(
              path: AppRoutes.business,
              name: 'business',
              builder: (context, state) => const BusinessPage(),
            ),
          ],
        ),
        
        // Service Details
        GoRoute(
          path: AppRoutes.serviceDetails,
          name: 'service_details',
          builder: (context, state) {
            final serviceId = state.uri.queryParameters['id'];
            return const Placeholder(); // TODO: Create service details page
          },
        ),
        GoRoute(
          path: AppRoutes.serviceBooking,
          name: 'service_booking',
          builder: (context, state) {
            final serviceId = state.uri.queryParameters['id'];
            return const Placeholder(); // TODO: Create service booking page
          },
        ),
        
        // Booking Management
        GoRoute(
          path: AppRoutes.bookingDetails,
          name: 'booking_details',
          builder: (context, state) {
            final bookingId = state.uri.queryParameters['id'];
            return const Placeholder(); // TODO: Create booking details page
          },
        ),
        GoRoute(
          path: AppRoutes.bookingConfirmation,
          name: 'booking_confirmation',
          builder: (context, state) {
            final bookingId = state.uri.queryParameters['id'];
            return const Placeholder(); // TODO: Create booking confirmation page
          },
        ),
        
        // Business Management
        GoRoute(
          path: AppRoutes.businessList,
          name: 'business_list',
          builder: (context, state) => const Placeholder(), // TODO: Create business list page
        ),
        GoRoute(
          path: AppRoutes.businessSetup,
          name: 'business_setup',
          builder: (context, state) => const Placeholder(), // TODO: Create business setup page
        ),
        GoRoute(
          path: AppRoutes.businessProfile,
          name: 'business_profile',
          builder: (context, state) {
            final businessId = state.uri.queryParameters['id'];
            return const Placeholder(); // TODO: Create business profile page
          },
        ),
        
        // Profile Management
        GoRoute(
          path: AppRoutes.editProfile,
          name: 'edit_profile',
          builder: (context, state) => const Placeholder(), // TODO: Create edit profile page
        ),
        GoRoute(
          path: AppRoutes.paymentMethods,
          name: 'payment_methods',
          builder: (context, state) => const Placeholder(), // TODO: Create payment methods page
        ),
        GoRoute(
          path: AppRoutes.favorites,
          name: 'favorites',
          builder: (context, state) => const Placeholder(),,,,; // TODO: Create favorites page
        ),
        
        // Settings
        GoRoute(
          path: AppRoutes.settings,
          name: 'settings',
          builder: (context, state) => const Placeholder(), // TODO: Create settings page
        ),
        GoRoute(
          path: AppRoutes.language,
          name: 'language',
          builder: (context, state) => const Placeholder(), // TODO: Create language page
        ),
        GoRoute(
          path: AppRoutes.theme,
          name: 'theme',
          builder: (context, state) => const Placeholder(), // TODO: Create theme page
        ),
        
        // Error Pages
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
      errorBuilder: (context, state) => NotFoundPage(error: state.error),
    );
  }
}

// Main Navigation with Bottom Navigation Bar
class MainNavigation extends StatefulWidget {
  
  const MainNavigation({
    required this.child, super.key,
  });
  final Widget child;
  
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  
  final List<NavigationItem> _navigationItems = [
    NavigationItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Home',
      route: AppRoutes.home,
    ),
    NavigationItem(
      icon: Icons.search_outlined,
      activeIcon: Icons.search,
      label: 'Services',
      route: AppRoutes.services,
    ),
    NavigationItem(
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_today,
      label: 'Bookings',
      route: AppRoutes.bookings,
    ),
    NavigationItem(
      icon: Icons.business_center_outlined,
      activeIcon: Icons.business_center,
      label: 'Business',
      route: AppRoutes.business,
    ),
    NavigationItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'Profile',
      route: AppRoutes.profile,
    ),
  ];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          context.go(_navigationItems[index].route);
        },
        type: BottomNavigationBarType.fixed,
        items: _navigationItems.map((item) {
          return BottomNavigationBarItem(
            icon: Icon(item.icon),
            activeIcon: Icon(item.activeIcon),
            label: item.label,
          );
        }).toList(),
      ),
    );
  }
}

class NavigationItem {
  
  NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
}

// Error Pages
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
            const Icon(Icons.error_outline, size: 64),
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
            const Icon(Icons.error, size: 64, color: Colors.red),
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
            const Icon(Icons.wifi_off, size: 64, color: Colors.orange),
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
