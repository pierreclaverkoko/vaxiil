import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vaxiil_mobile/core/constants/app_constants.dart';

/// Soft health UI: Stitch-aligned sage scaffold, forest greens, mint CTAs, Plus Jakarta Sans.
class AppTheme {
  /// Stitch `primary` — main brand green.
  static const Color primaryColor = Color(0xFF0D631B);
  /// Stitch `primary-container` emphasis / legacy “forest” accent.
  static const Color primaryVariant = Color(0xFF2E7D32);
  static const Color secondaryColor = Color(0xFF43A047);
  static const Color secondaryVariant = Color(0xFF388E3C);

  /// Primary actions: light mint fill + dark green label (Stitch CTA).
  static const Color ctaFill = Color(0xFFC8E6C9);
  static const Color onCtaFill = Color(0xFF0D631B);

  /// Avatar ring on frosted bar (Stitch `c8e6c9` @ ~30% alpha).
  static const Color avatarBorderMuted = Color(0x4DC8E6C9);

  /// Legacy names — map to soft-health CTAs (avoid amber).
  static const Color accentCta = ctaFill;
  static const Color accentCtaDark = Color(0xFFA5D6A7);
  static const Color onAccentCta = onCtaFill;

  static const Color backgroundColor = Color(0xFFF1FCF1);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color errorColor = Color(0xFFE53935);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color successColor = Color(0xFF4CAF50);

  static const Color textPrimary = Color(0xFF141E17);
  static const Color textSecondary = Color(0xFF40493D);
  static const Color textDisabled = Color(0xFFB0BEC5);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  static const Color borderColor = Color(0xFFBFCABA);
  static const Color dividerColor = Color(0xFFE0EBE0);

  /// Peach accent (reference UI) for highlights and alternate circular actions.
  static const Color accentPeach = Color(0xFFFFD8A8);
  static const Color onAccentPeach = Color(0xFF3E2723);

  /// ~rgba(0,0,0,0.05) for card elevation.
  static const Color shadowColor = Color(0x0D000000);

  static const Color navBarBackground = Color(0xFFE6F1E6);
  static const Color navBarIconSelectedBg = Color(0x332E7D32);

  /// Stitch editorial card shadow (0 20px 40px ~rgba(20,30,23,0.06)).
  static List<BoxShadow> get editorialShadow => [
        BoxShadow(
          color: const Color(0xFF141E17).withOpacity(0.06),
          offset: const Offset(0, 20),
          blurRadius: 40,
        ),
      ];

  static BoxDecoration frostedTopBarDecoration(ColorScheme colorScheme) {
    return BoxDecoration(
      color: colorScheme.surface.withOpacity(0.82),
      boxShadow: editorialShadow,
    );
  }

  static const List<Color> primaryGradient = [primaryColor, secondaryColor];
  static const List<Color> secondaryGradient = [secondaryColor, primaryVariant];

  static ThemeData get lightTheme => _buildLightTheme(); // ignore: prefer_const_constructors

  static ThemeData get darkTheme => _buildDarkTheme();

  static ThemeData _buildLightTheme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primarySwatch: Colors.green,
    );

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    final primaryTextTheme =
        GoogleFonts.plusJakartaSansTextTheme(base.primaryTextTheme);

    final lightColorScheme = ColorScheme.light(
      primary: primaryColor,
      onPrimary: textOnPrimary,
      primaryContainer: primaryVariant,
      onPrimaryContainer: const Color(0xFFCBFFC2),
      secondary: const Color(0xFF4A654E),
      onSecondary: textOnPrimary,
      secondaryContainer: const Color(0xFFC9E7CA),
      onSecondaryContainer: const Color(0xFF4E6952),
      // Cards / in-scaffold surfaces (scaffoldBackgroundColor stays mint).
      surface: surfaceColor,
      onSurface: textPrimary,
      surfaceContainerHighest: const Color(0xFFDAE5DB),
      surfaceContainerHigh: const Color(0xFFE0EBE0),
      surfaceContainer: const Color(0xFFE6F1E6),
      surfaceContainerLow: const Color(0xFFECF7EB),
      surfaceContainerLowest: surfaceColor,
      onSurfaceVariant: textSecondary,
      error: errorColor,
      onError: textOnPrimary,
      outline: const Color(0xFF707A6C),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primarySwatch: Colors.green,
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      textTheme: textTheme,
      primaryTextTheme: primaryTextTheme,
      colorScheme: lightColorScheme,
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ctaFill,
          foregroundColor: onCtaFill,
          elevation: 0,
          shadowColor: shadowColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: onCtaFill,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ctaFill,
          foregroundColor: onCtaFill,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: onCtaFill,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryVariant,
          side: const BorderSide(color: primaryColor, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: const BorderSide(color: errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: GoogleFonts.plusJakartaSans(color: textSecondary, fontSize: 15),
        labelStyle: GoogleFonts.plusJakartaSans(color: textSecondary, fontSize: 15),
      ),
      cardTheme: CardTheme(
        color: cardColor,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusCard),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: backgroundColor,
        selectedColor: primaryColor.withOpacity(0.12),
        labelStyle: GoogleFonts.plusJakartaSans(color: textPrimary),
        secondaryLabelStyle: GoogleFonts.plusJakartaSans(color: textOnPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: navBarBackground,
        selectedItemColor: primaryVariant,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontSize: 12),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: ctaFill,
        foregroundColor: onCtaFill,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
        linearTrackColor: backgroundColor,
        circularTrackColor: backgroundColor,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor.withOpacity(0.35);
          }
          return textSecondary.withOpacity(0.28);
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(textOnPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return textSecondary;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        inactiveTrackColor: borderColor,
        thumbColor: primaryColor,
        overlayColor: primaryColor.withOpacity(0.2),
        valueIndicatorColor: primaryVariant,
        valueIndicatorTextStyle: const TextStyle(color: textOnPrimary),
      ),
      extensions: <ThemeExtension<dynamic>>[
        VaxiilMainNavTheme.light(lightColorScheme),
      ],
    );
  }

  static ThemeData _buildDarkTheme() {
    const darkSurface = Color(0xFF1E1E1E);
    const darkCard = Color(0xFF252525);

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
    );

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    );

    final darkColorScheme = ColorScheme.dark(
      primary: primaryColor,
      onPrimary: textOnPrimary,
      primaryContainer: primaryVariant,
      secondary: ctaFill,
      onSecondary: onCtaFill,
      surface: darkSurface,
      surfaceContainerHigh: const Color(0xFF2C2C2C),
      error: errorColor,
      onError: textOnPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primarySwatch: Colors.green,
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      textTheme: textTheme,
      primaryTextTheme:
          GoogleFonts.plusJakartaSansTextTheme(base.primaryTextTheme),
      scaffoldBackgroundColor: darkSurface,
      colorScheme: darkColorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ctaFill,
          foregroundColor: onCtaFill,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: onCtaFill,
          ),
        ),
      ),
      cardTheme: CardTheme(
        color: darkCard,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusCard),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: const BorderSide(color: Color(0xFF404040)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: const BorderSide(color: Color(0xFF404040)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: const BorderSide(color: errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF9E9E9E)),
        labelStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF9E9E9E)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: secondaryColor,
        unselectedItemColor: const Color(0xFF9E9E9E),
        type: BottomNavigationBarType.fixed,
        elevation: 12,
        selectedLabelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontSize: 12),
      ),
      extensions: <ThemeExtension<dynamic>>[
        VaxiilMainNavTheme.dark(darkColorScheme),
      ],
    );
  }

  static TextStyle kButtonTextStyle = GoogleFonts.plusJakartaSans(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: onCtaFill,
  );

  static TextStyle kCardTitleStyle = GoogleFonts.plusJakartaSans(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static TextStyle kCardSubtitleStyle = GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: textSecondary,
  );

  static TextStyle kPriceStyle = GoogleFonts.plusJakartaSans(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: primaryColor,
  );

  static TextStyle kRatingStyle = GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: warningColor,
  );

  static const LinearGradient primaryLinearGradient = LinearGradient(
    colors: primaryGradient,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryLinearGradient = LinearGradient(
    colors: secondaryGradient,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Splash / hero: lighter leaf green at top, forest at bottom.
  static const LinearGradient splashVerticalGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF66BB6A),
      Color(0xFF2E7D32),
      Color(0xFF1B5E20),
    ],
    stops: [0.0, 0.55, 1.0],
  );

  /// Business profile: lime top to deep charcoal-green bottom (reference UI).
  static const LinearGradient businessProfileGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFBEE6A1),
      Color(0xFF2E7D32),
      Color(0xFF1A2E1A),
    ],
    stops: [0.0, 0.45, 1.0],
  );

  /// Soft shadow for cards (~0 10px 20px rgba(0,0,0,0.05)).
  static List<BoxShadow> get cardShadow => [
        const BoxShadow(
          color: shadowColor,
          blurRadius: 20,
          offset: Offset(0, 10),
        ),
      ];

  static List<BoxShadow> get elevatedCardShadow => [
        const BoxShadow(
          color: shadowColor,
          blurRadius: 24,
          spreadRadius: -2,
          offset: Offset(0, 12),
        ),
      ];

  static List<BoxShadow> get navBarShadow => [
        const BoxShadow(
          color: shadowColor,
          blurRadius: 16,
          offset: Offset(0, -4),
        ),
      ];
}

/// Colors for the main floating pill nav (theme-coupled; no hex in widgets).
class VaxiilMainNavTheme extends ThemeExtension<VaxiilMainNavTheme> {
  const VaxiilMainNavTheme({
    required this.pillSurface,
    required this.selectedFill,
    required this.selectedForeground,
    required this.unselectedForeground,
  });

  final Color pillSurface;
  final Color selectedFill;
  final Color selectedForeground;
  final Color unselectedForeground;

  factory VaxiilMainNavTheme.light(ColorScheme cs) {
    return VaxiilMainNavTheme(
      pillSurface: cs.surfaceContainerHigh.withOpacity(0.92),
      selectedFill: AppTheme.accentPeach,
      selectedForeground: AppTheme.onAccentPeach,
      unselectedForeground: cs.primary.withOpacity(0.55),
    );
  }

  factory VaxiilMainNavTheme.dark(ColorScheme cs) {
    return VaxiilMainNavTheme(
      pillSurface: cs.surfaceContainerHigh.withOpacity(0.92),
      selectedFill: AppTheme.accentPeach,
      selectedForeground: AppTheme.onAccentPeach,
      unselectedForeground: cs.primary.withOpacity(0.65),
    );
  }

  @override
  VaxiilMainNavTheme copyWith({
    Color? pillSurface,
    Color? selectedFill,
    Color? selectedForeground,
    Color? unselectedForeground,
  }) {
    return VaxiilMainNavTheme(
      pillSurface: pillSurface ?? this.pillSurface,
      selectedFill: selectedFill ?? this.selectedFill,
      selectedForeground: selectedForeground ?? this.selectedForeground,
      unselectedForeground: unselectedForeground ?? this.unselectedForeground,
    );
  }

  @override
  VaxiilMainNavTheme lerp(ThemeExtension<VaxiilMainNavTheme>? other, double t) {
    if (other is! VaxiilMainNavTheme) return this;
    return VaxiilMainNavTheme(
      pillSurface: Color.lerp(pillSurface, other.pillSurface, t)!,
      selectedFill: Color.lerp(selectedFill, other.selectedFill, t)!,
      selectedForeground:
          Color.lerp(selectedForeground, other.selectedForeground, t)!,
      unselectedForeground:
          Color.lerp(unselectedForeground, other.unselectedForeground, t)!,
    );
  }
}
