import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Semantic editorial / discovery typography (Stitch-aligned). Uses
/// [ThemeData.colorScheme] from the app theme.
class VaxiilText {
  VaxiilText._(this._colorScheme);

  final ColorScheme _colorScheme;

  static VaxiilText of(BuildContext context) =>
      VaxiilText._(Theme.of(context).colorScheme);

  TextStyle get greeting => GoogleFonts.plusJakartaSans(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        height: 1.15,
        letterSpacing: -0.25,
        color: _colorScheme.primary,
      );

  TextStyle get discoverySubtitle => GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: _colorScheme.onSurfaceVariant,
      );

  TextStyle get sectionTitle => GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
        color: _colorScheme.primary,
      );

  TextStyle get body16OnSurface => GoogleFonts.plusJakartaSans(
        fontSize: 16,
        color: _colorScheme.onSurface,
      );

  TextStyle get categoryLabel => GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: _colorScheme.onSurfaceVariant,
      );

  TextStyle get featuredBadge => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: _colorScheme.primary,
      );

  TextStyle get cardTitle => GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: _colorScheme.onSurface,
      );

  TextStyle get pricePrimary => GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: _colorScheme.primaryContainer,
      );

  TextStyle get priceSuffix => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: _colorScheme.onSurfaceVariant,
      );

  TextStyle get bookNow => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: _colorScheme.primary,
      );

  TextStyle get drawerItem => GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w600,
      );

  TextStyle get venueTitle => GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: _colorScheme.onSurface,
      );

  TextStyle get venueBody => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: _colorScheme.onSurfaceVariant,
      );

  TextStyle get venueMeta => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: _colorScheme.primary,
      );

  TextStyle get cityPill => GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _colorScheme.primary,
      );

  TextStyle get frostedAppBarTitle => GoogleFonts.plusJakartaSans(
        fontSize: 24,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
        color: _colorScheme.primary,
      );

  TextStyle get viewAllLink => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: _colorScheme.primary,
      );
}
