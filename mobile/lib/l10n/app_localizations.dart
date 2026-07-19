import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr')
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'Vaxiil'**
  String get appTitle;

  /// Language settings screen title
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// Language settings helper text
  ///
  /// In en, this message translates to:
  /// **'Choose the language for the app and API messages.'**
  String get languageSubtitle;

  /// English language option label
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// French language option label
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get languageFrench;

  /// Snackbar after changing language
  ///
  /// In en, this message translates to:
  /// **'Language updated'**
  String get languageSaved;

  /// Login OTP step instructions
  ///
  /// In en, this message translates to:
  /// **'Enter the verification code sent to your email.'**
  String get loginOtpLede;

  /// Login OTP code field label
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get loginOtpCode;

  /// Login OTP validation message
  ///
  /// In en, this message translates to:
  /// **'Enter the verification code.'**
  String get loginOtpRequired;

  /// Login OTP submit button
  ///
  /// In en, this message translates to:
  /// **'Verify and sign in'**
  String get loginVerifyOtp;

  /// Cancel OTP challenge and return to password form
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get loginOtpBack;

  /// Profile escrow wallet card title
  ///
  /// In en, this message translates to:
  /// **'Escrow balance'**
  String get escrowBalanceTitle;

  /// Profile escrow wallet helper text
  ///
  /// In en, this message translates to:
  /// **'Store credit from cancellations or top-ups. Apply it at checkout on your next booking.'**
  String get escrowBalanceHint;

  /// Escrow top-up button
  ///
  /// In en, this message translates to:
  /// **'Add funds'**
  String get escrowTopUp;

  /// Escrow top-up amount field
  ///
  /// In en, this message translates to:
  /// **'Amount to add'**
  String get escrowTopUpAmount;

  /// Escrow top-up submit button
  ///
  /// In en, this message translates to:
  /// **'Continue to payment'**
  String get escrowTopUpSubmit;

  /// Escrow top-up helper text
  ///
  /// In en, this message translates to:
  /// **'Add funds securely to your escrow balance.'**
  String get escrowTopUpHint;

  /// Pay dialog title for applying escrow
  ///
  /// In en, this message translates to:
  /// **'Use escrow credit?'**
  String get payUseEscrowTitle;

  /// Pay dialog body showing escrow balance
  ///
  /// In en, this message translates to:
  /// **'You have {balance} {currency} in escrow. Apply it to this payment?'**
  String payUseEscrowBody(String balance, String currency);

  /// Label for escrow amount applied to payment
  ///
  /// In en, this message translates to:
  /// **'Escrow applied'**
  String get payEscrowApplied;

  /// Remaining amount after escrow for hosted checkout
  ///
  /// In en, this message translates to:
  /// **'Amount to pay now'**
  String get payCardAmount;

  /// Snackbar when escrow covers the full booking
  ///
  /// In en, this message translates to:
  /// **'Paid with escrow credit.'**
  String get payFullyPaidEscrow;

  /// Confirm applying escrow
  ///
  /// In en, this message translates to:
  /// **'Yes, use credit'**
  String get payUseEscrowYes;

  /// Decline applying escrow
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get payUseEscrowNo;

  /// Cancel success when refund goes to escrow
  ///
  /// In en, this message translates to:
  /// **'Booking cancelled. {amount} {currency} credited to escrow.'**
  String bookingCancelledEscrowCredit(String amount, String currency);

  /// Business booking detail venue section
  ///
  /// In en, this message translates to:
  /// **'Venue'**
  String get businessBookingVenue;

  /// Business booking detail special requests section
  ///
  /// In en, this message translates to:
  /// **'Special requests'**
  String get businessBookingSpecialRequests;

  /// Message when Book is gated on KYC
  ///
  /// In en, this message translates to:
  /// **'Verify your identity before booking.'**
  String get kycRequiredForBooking;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'fr': return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
