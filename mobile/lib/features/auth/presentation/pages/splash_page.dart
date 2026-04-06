import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/storage/secure_storage_service.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_state.dart';

/// Stitch-based splash and onboarding: imagery grid, headline, service chips, CTA.
class SplashPage extends StatefulWidget {
  /// Creates the splash / onboarding screen.
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthCubit>().checkSession();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _continueFromOnboarding() async {
    await sl<SecureStorageService>().setOnboardingComplete();
    if (!mounted) return;
    final authed =
        context.read<AuthCubit>().state.status == AuthStatus.authenticated;
    context.go(authed ? AppRoutes.home : AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(theme.textTheme);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: _OnboardingColors.background,
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: Theme(
            data: theme.copyWith(
              textTheme: textTheme,
              brightness: Brightness.light,
            ),
            child: Stack(
              children: [
                _DecorativeGlows(),
                SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(onSkip: _continueFromOnboarding),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 0),
                          child: Column(
                            children: [
                              _BentoImageGrid(),
                              SizedBox(height: 28.h),
                              _HeadlineBlock(),
                              SizedBox(height: 20.h),
                            ],
                          ),
                        ),
                      ),
                      _Footer(
                        onGetStarted: _continueFromOnboarding,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingColors {
  static const Color background = Color(0xFFF1FCF1);
  static const Color onSurface = Color(0xFF141E17);
  static const Color onSurfaceVariant = Color(0xFF40493D);
  static const Color primary = Color(0xFF0D631B);
  static const Color primaryContainer = Color(0xFF2E7D32);
  static const Color primaryOrange = Color(0xFFF57C00);
  static const Color secondaryFixed = Color(0xFFCCEACD);
  static const Color onPrimaryFixedVariant = Color(0xFF005312);
  static const Color onSecondaryFixedVariant = Color(0xFF334D37);
  static const Color surfaceContainerLow = Color(0xFFECF7EB);
  static const Color surfaceContainer = Color(0xFFE6F1E6);
  static const Color surfaceContainerHigh = Color(0xFFE0EBE0);
  static const Color surfaceContainerHighest = Color(0xFFDAE5DB);
  static const Color secondaryContainer = Color(0xFFC9E7CA);
  static const Color outlineVariant = Color(0xFFBFCABA);
  static const Color outline = Color(0xFF707A6C);
}

/// Stitch "Splash & Onboarding Refined" header logo (same URL as HTML export).
const _kSplashLogoUrl =
    'https://lh3.googleusercontent.com/aida/ADBb0uhaeaP9v5NZtqMR_0GwfPncfCLlFVvEtJtJZ0HqkHLKVy64ACNnFmm64d4y22OjxbiqOYsisv_nUiTu5WBq-mkj24WtOqWkEpZC2FPwPp188aAY9su7t7pFYsN-p1IqJnN441W-Mh3c4J__KjNlIJ2SiNpXA6OQsQPljM3iduxuVRFb1ESGmeFwzq2Q4WJABt0FiTv46XLq_JBrFBv7KYUjHfnV8jIHYvf2YxKNbyk_tu5Vy9Ht3ZQ4Q4dIeioYINtpquVHQoLVkw';

/// Same imagery as Stitch HTML export (lh3 aida-public).
const _kBentoLarge =
    'https://lh3.googleusercontent.com/aida-public/AB6AXuAfG658a4_-ZknyheLkvDrO9FUeXZthlgsFHZlwFalRd27g8tJBE5qTENBM_F5VwVXVV4cBwKHr2FjhTpIazV72ZWmA1TfyltTWoG9dCVqme2i8diU-j1SEIJsg6JuX3Umy7XZaGLlz0i4iP43d5Ncg9S8FEUXEBjs7TCLjgj7TYYFA5zpg8qkh495SlYpy2F3Ctmczfy6c5PSz8NxMdxYCueX6oAjTsSfEcN9pWZSs4YBWLHzm_GQRUHUrJDN9MjN0r7BWKowyVtc';
const _kBentoSideTop =
    'https://lh3.googleusercontent.com/aida-public/AB6AXuDc7QsS32ITZ2PXmr0VWb0y7KFNfol8q7kEbdrD8jlxNvjjHO8lT68jbOmOlsIkoHQdokSgIIzr-IflkHAORAgpMmXFn6iB2lSidR_rA4MyfSzZ7IB57cE6Id09OvA2zeym5q_QvymqXXHsleDUT4HESNftf-b4LTHOW6WsknP70jCwMMJYL5pzkVX9A8f2pUIasETwaw6rO6syVLv0w8U6ssgUAo3em01NgVhMguRxKcnPrIyn2hMDyZGoQjI-ByB4IOzfzhGT4jY';
const _kBentoSideBottom =
    'https://lh3.googleusercontent.com/aida-public/AB6AXuD16uJxhwtXJ9efL9ibOzLWpDdqmmB-RfjBYp82G5EdRdTdLiHaZDErNPDCF6VwfTCFfBvkQJOLFPQx4-g0RBj_orLXBgryzSrisqgGWMlhxVtTUsSuWbAZmPCpG0LqaEdABnx2ErMGPUOvOf0xz50NBK11BE5SiBFFbHi3IYIkXUpHPZWCN3Q6W_tSwJeK0mb1Q0LwHqeyFaxZNUiC1g2DWh2a1cUwJGspIOoW7SQsOwW7wF4UIY-zqyivS1q2IF2qn_mx6eWXJEc';
const _kBentoWide =
    'https://lh3.googleusercontent.com/aida-public/AB6AXuAhWUmiaMLD4jm4_PUi3P6_rDxJgzDmV4iNZPFSU1tpFqvet6GDEEMBd5dbeUhGfv6WPse-zwIHiEYiIC7KHwIsen8gtHEZOtkXBrZqD_JsbwRWuSKZrkZz72Bv8JgpfugE1ro5H19YpORdu1DSDW4b6v0s09faAR54l13baSHA5P3YWNdNB3YPWClF7L3fE4WFa-fxIlFln5bzFliH3wshdE_xuwVQByXkO7E4CDvELqAHALGvcaO1eTGb9NID9-M4Yg-3tJLdyRc';

class _DecorativeGlows extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -0.1.sh,
            right: -0.05.sw,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(
                width: 256.w,
                height: 256.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _OnboardingColors.secondaryContainer.withOpacity(0.2),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -0.05.sh,
            left: -0.05.sw,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(
                width: 384.w,
                height: 384.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _OnboardingColors.primaryContainer.withOpacity(0.1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onSkip});

  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(28.w, 16.h, 28.w, 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Semantics(
            label: 'Vaxiil',
            child: SizedBox(
              height: 32.h,
              child: CachedNetworkImage(
                imageUrl: _kSplashLogoUrl,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
                placeholder: (_, __) => SizedBox(
                  width: 96.w,
                  height: 32.h,
                  child: Center(
                    child: SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _OnboardingColors.primaryContainer,
                      ),
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Text(
                  'Vaxiil',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: _OnboardingColors.primaryContainer,
                  ),
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(
              foregroundColor: _OnboardingColors.primary,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: Text(
              'Skip',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BentoImageGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final gap = 8.w;
    final rowHeight = 118.h;

    return Column(
      children: [
        SizedBox(
          height: rowHeight * 2 + gap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 8,
                child: _BentoTile(
                  borderRadius: 16.r,
                  shadowOpacity: 0.06,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _NetworkCover(_kBentoLarge),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              _OnboardingColors.primary.withOpacity(0.2),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    Expanded(
                      child: _BentoTile(
                        borderRadius: 16.r,
                        shadowOpacity: 0.04,
                        color: _OnboardingColors.surfaceContainerHigh,
                        child: _NetworkCover(_kBentoSideTop),
                      ),
                    ),
                    SizedBox(height: gap),
                    Expanded(
                      child: _BentoTile(
                        borderRadius: 16.r,
                        shadowOpacity: 0.04,
                        color: _OnboardingColors.surfaceContainerHighest,
                        child: _NetworkCover(_kBentoSideBottom),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: gap),
        SizedBox(
          height: rowHeight,
          child: _BentoTile(
            borderRadius: 16.r,
            shadowOpacity: 0.06,
            child: _NetworkCover(_kBentoWide),
          ),
        ),
      ],
    );
  }
}

class _BentoTile extends StatelessWidget {
  const _BentoTile({
    required this.child,
    required this.borderRadius,
    required this.shadowOpacity,
    this.color,
  });

  final Widget child;
  final double borderRadius;
  final double shadowOpacity;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? _OnboardingColors.surfaceContainer,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF141E17).withOpacity(shadowOpacity),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: child,
      ),
    );
  }
}

class _NetworkCover extends StatelessWidget {
  const _NetworkCover(this.url);

  final String url;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => ColoredBox(
        color: _OnboardingColors.surfaceContainerHigh,
        child: Center(
          child: SizedBox(
            width: 24.w,
            height: 24.w,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              color: _OnboardingColors.primaryContainer,
            ),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => ColoredBox(
        color: _OnboardingColors.surfaceContainerHigh,
        child: Icon(
          Icons.image_not_supported_outlined,
          color: _OnboardingColors.outline,
          size: 32.sp,
        ),
      ),
    );
  }
}

class _HeadlineBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text.rich(
          TextSpan(
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28.sp,
              fontWeight: FontWeight.w700,
              height: 1.12,
              letterSpacing: -0.4,
              color: _OnboardingColors.onSurface,
            ),
            children: [
              const TextSpan(text: 'Your sanctuary for\n'),
              TextSpan(
                text: 'holistic restoration.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                  color: _OnboardingColors.primary,
                  height: 1.12,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 16.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w),
          child: Text(
            'Experience premium Massage, focused Therapy, and exquisite Room Rentals '
            'designed for your complete well-being.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16.sp,
              height: 1.5,
              color: _OnboardingColors.onSurfaceVariant.withOpacity(0.9),
            ),
          ),
        ),
        SizedBox(height: 12.h),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10.w,
          runSpacing: 10.h,
          children: const [
            _ServiceChip(
              icon: Icons.spa,
              label: 'Massage',
            ),
            _ServiceChip(
              icon: Icons.psychology,
              label: 'Therapy',
            ),
            _ServiceChip(
              icon: Icons.bedroom_parent_outlined,
              label: 'Room Rentals',
            ),
          ],
        ),
      ],
    );
  }
}

class _ServiceChip extends StatelessWidget {
  const _ServiceChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: _OnboardingColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18.sp, color: _OnboardingColors.onSecondaryFixedVariant),
          SizedBox(width: 6.w),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: _OnboardingColors.onSecondaryFixedVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.onGetStarted});

  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(28.w, 8.h, 28.w, 28.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 24.w,
                height: 6.h,
                decoration: BoxDecoration(
                  color: _OnboardingColors.primaryOrange,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              SizedBox(width: 6.w),
              Container(
                width: 6.w,
                height: 6.w,
                decoration: BoxDecoration(
                  color: _OnboardingColors.outlineVariant,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                width: 6.w,
                height: 6.w,
                decoration: BoxDecoration(
                  color: _OnboardingColors.outlineVariant,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF141E17).withOpacity(0.1),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: FilledButton(
                onPressed: onGetStarted,
                style: FilledButton.styleFrom(
                  backgroundColor: _OnboardingColors.secondaryFixed,
                  foregroundColor: _OnboardingColors.onPrimaryFixedVariant,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 24.w),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Get Started',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Icon(
                      Icons.arrow_forward,
                      size: 22.sp,
                      color: _OnboardingColors.primaryOrange,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            'Step into tranquility',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.6,
              color: _OnboardingColors.outline,
            ),
          ),
        ],
      ),
    );
  }
}
