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

  /// Email verification screen title
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get emailVerifyTitle;

  /// Email verification instructions
  ///
  /// In en, this message translates to:
  /// **'Enter the code we sent to {email} to continue.'**
  String emailVerifyLede(String email);

  /// Email verification OTP field label
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get emailVerifyCode;

  /// Email verification validation
  ///
  /// In en, this message translates to:
  /// **'Enter the verification code.'**
  String get emailVerifyCodeRequired;

  /// Email verification primary CTA
  ///
  /// In en, this message translates to:
  /// **'Verify email'**
  String get emailVerifySubmit;

  /// Email verification busy label
  ///
  /// In en, this message translates to:
  /// **'Verifying…'**
  String get emailVerifySubmitting;

  /// Email verification resend CTA
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get emailVerifyResend;

  /// Email verification code sent status
  ///
  /// In en, this message translates to:
  /// **'A verification code was sent to your email.'**
  String get emailVerifySent;

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

  /// Shown when Turnstile token is missing before submit
  ///
  /// In en, this message translates to:
  /// **'Please complete the security check.'**
  String get turnstileRequired;

  /// Forgot password screen title
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get forgotPasswordTitle;

  /// Forgot password screen instructions
  ///
  /// In en, this message translates to:
  /// **'We will email you a one-time code to set a new password.'**
  String get forgotPasswordLede;

  /// Forgot password email field
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get forgotPasswordEmail;

  /// Forgot password email validation
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email.'**
  String get forgotPasswordEmailRequired;

  /// Request password reset OTP
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get forgotPasswordSendCode;

  /// Confirm password reset
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get forgotPasswordReset;

  /// New password field on reset confirm
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get forgotPasswordNewPassword;

  /// New password validation
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get forgotPasswordPasswordShort;

  /// After requesting reset code
  ///
  /// In en, this message translates to:
  /// **'If an account exists for this email, a code was sent.'**
  String get forgotPasswordCodeSent;

  /// After successful password reset
  ///
  /// In en, this message translates to:
  /// **'Password reset complete. You can sign in now.'**
  String get forgotPasswordDone;

  /// Link back to login from forgot password
  ///
  /// In en, this message translates to:
  /// **'Back to login'**
  String get forgotPasswordBackToLogin;

  /// Missing challenge id on confirm step
  ///
  /// In en, this message translates to:
  /// **'Request a new code first.'**
  String get forgotPasswordMissingChallenge;

  /// Profile store credit wallet card title
  ///
  /// In en, this message translates to:
  /// **'Store credit'**
  String get escrowBalanceTitle;

  /// Profile store credit wallet helper text
  ///
  /// In en, this message translates to:
  /// **'Store credit from cancellations or top-ups. Apply it at checkout on your next booking.'**
  String get escrowBalanceHint;

  /// Store credit top-up button
  ///
  /// In en, this message translates to:
  /// **'Add funds'**
  String get escrowTopUp;

  /// Store credit top-up amount field
  ///
  /// In en, this message translates to:
  /// **'Amount to add'**
  String get escrowTopUpAmount;

  /// Store credit top-up submit button
  ///
  /// In en, this message translates to:
  /// **'Add funds'**
  String get escrowTopUpSubmit;

  /// Store credit top-up helper text
  ///
  /// In en, this message translates to:
  /// **'Choose a method and phone number to fund your store credit.'**
  String get escrowTopUpHint;

  /// Shown after wallet top-up collection is started
  ///
  /// In en, this message translates to:
  /// **'Approve the payment on your phone. Credit appears when it completes.'**
  String get escrowTopUpPending;

  /// Store credit top-up blocked until KYC verified
  ///
  /// In en, this message translates to:
  /// **'Verify your identity before adding funds.'**
  String get escrowTopUpKycRequired;

  /// CTA from wallet card to KYC flow
  ///
  /// In en, this message translates to:
  /// **'Complete identity verification'**
  String get escrowTopUpKycCta;

  /// Collect sheet title
  ///
  /// In en, this message translates to:
  /// **'Pay securely'**
  String get paymentCollectTitle;

  /// Payment wizard go to confirm step
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get paymentWizardReview;

  /// Payment wizard confirm step title
  ///
  /// In en, this message translates to:
  /// **'Confirm payment'**
  String get paymentWizardConfirm;

  /// Payment method country filter
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get paymentWizardCountry;

  /// Payment method country filter clear option
  ///
  /// In en, this message translates to:
  /// **'All countries'**
  String get paymentWizardCountryAll;

  /// Payment wizard currency label
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get paymentWizardCurrency;

  /// Generic back action
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// Collect sheet method dropdown
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get paymentMethodLabel;

  /// Collect sheet phone field
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get paymentPhoneLabel;

  /// Collect sheet email field
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get paymentEmailLabel;

  /// Generic account identifier label
  ///
  /// In en, this message translates to:
  /// **'Account number / IBAN / phone / email'**
  String get paymentAccountIdentifierLabel;

  /// Phone dial code picker
  ///
  /// In en, this message translates to:
  /// **'Country code'**
  String get paymentDialCode;

  /// Phone field hint
  ///
  /// In en, this message translates to:
  /// **'National number'**
  String get paymentPhonePlaceholder;

  /// Email field hint
  ///
  /// In en, this message translates to:
  /// **'name@example.com'**
  String get paymentEmailPlaceholder;

  /// Generic account field hint
  ///
  /// In en, this message translates to:
  /// **'Account number, IBAN, or identifier'**
  String get paymentGenericPlaceholder;

  /// Missing account identifier
  ///
  /// In en, this message translates to:
  /// **'Enter an account identifier.'**
  String get paymentAccountRequired;

  /// Invalid email on payment form
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get paymentEmailInvalid;

  /// Collect sheet account name
  ///
  /// In en, this message translates to:
  /// **'Account name (optional)'**
  String get paymentAccountNameLabel;

  /// Collect sheet submit
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get paymentCollectSubmit;

  /// Collect sheet load error
  ///
  /// In en, this message translates to:
  /// **'Could not load payment methods.'**
  String get paymentMethodsLoadError;

  /// Collect sheet empty
  ///
  /// In en, this message translates to:
  /// **'No payment methods available.'**
  String get paymentMethodsEmpty;

  /// After booking collect started / processing payment on booking detail
  ///
  /// In en, this message translates to:
  /// **'Payment is processing. Approve it on your phone if prompted. Tap Refresh status to check with your payment provider.'**
  String get payCollectPending;

  /// Pay dialog title for applying store credit
  ///
  /// In en, this message translates to:
  /// **'Use store credit?'**
  String get payUseEscrowTitle;

  /// Pay dialog body showing store credit balance
  ///
  /// In en, this message translates to:
  /// **'You have {balance} {currency} in store credit. Apply it to this payment?'**
  String payUseEscrowBody(String balance, String currency);

  /// Label for store credit amount applied to payment
  ///
  /// In en, this message translates to:
  /// **'Store credit applied'**
  String get payEscrowApplied;

  /// Remaining amount after store credit for hosted checkout
  ///
  /// In en, this message translates to:
  /// **'Amount to pay now'**
  String get payCardAmount;

  /// Snackbar when store credit covers the full booking
  ///
  /// In en, this message translates to:
  /// **'Paid with store credit.'**
  String get payFullyPaidEscrow;

  /// Confirm applying store credit
  ///
  /// In en, this message translates to:
  /// **'Yes, use credit'**
  String get payUseEscrowYes;

  /// Decline applying store credit
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get payUseEscrowNo;

  /// Inline cancel form title
  ///
  /// In en, this message translates to:
  /// **'Cancel booking'**
  String get bookingCancelTitle;

  /// Confirm cancel button
  ///
  /// In en, this message translates to:
  /// **'Confirm cancellation'**
  String get bookingCancelConfirmAction;

  /// Cancel reason field label
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get bookingCancelReasonOptional;

  /// Warning when client cancels inside 24h window
  ///
  /// In en, this message translates to:
  /// **'This appointment starts in less than 24 hours. If you cancel now, you will receive 50% of what you paid as store credit. Of the remaining half, 80% stays with the business and 20% goes to Vaxiil.'**
  String get bookingCancelLateWarning;

  /// Cancel success when refund goes to store credit
  ///
  /// In en, this message translates to:
  /// **'Booking cancelled. {amount} {currency} credited to store credit.'**
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

  /// Booking schedule location section
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get bookingLocationTitle;

  /// Location option: office/venue
  ///
  /// In en, this message translates to:
  /// **'At venue'**
  String get bookingLocationOffice;

  /// Location option: client home
  ///
  /// In en, this message translates to:
  /// **'At my home'**
  String get bookingLocationHome;

  /// Location option: virtual
  ///
  /// In en, this message translates to:
  /// **'Virtual / online'**
  String get bookingLocationVirtual;

  /// Location option: mobile
  ///
  /// In en, this message translates to:
  /// **'Mobile service'**
  String get bookingLocationMobile;

  /// Business booking base price row
  ///
  /// In en, this message translates to:
  /// **'Service price'**
  String get businessBookingFeeBase;

  /// Business booking platform fee row
  ///
  /// In en, this message translates to:
  /// **'Platform fee'**
  String get businessBookingFeePlatform;

  /// Business booking total row
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get businessBookingFeeTotal;

  /// Business booking net captured payment
  ///
  /// In en, this message translates to:
  /// **'Net captured'**
  String get businessBookingNetCaptured;

  /// Badge when booking payment is captured
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get bookingPaidBadge;

  /// Badge when booking is not yet paid
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get bookingUnpaidBadge;

  /// Badge when booking payment was refunded
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get bookingRefundedBadge;

  /// Badge when booking payment collect is in flight
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get bookingProcessingBadge;

  /// Alert title on unpaid pending booking list card
  ///
  /// In en, this message translates to:
  /// **'ACTION REQUIRED'**
  String get bookingActionRequired;

  /// Alert body on unpaid pending booking list card
  ///
  /// In en, this message translates to:
  /// **'Complete any steps from your provider before the session.'**
  String get bookingActionRequiredBody;

  /// Alert title on paid pending booking list card
  ///
  /// In en, this message translates to:
  /// **'AWAITING APPROVAL'**
  String get bookingAwaitingApproval;

  /// Alert body on paid pending booking list card
  ///
  /// In en, this message translates to:
  /// **'Waiting for company approval.'**
  String get bookingAwaitingApprovalBody;

  /// CTA to open booking detail from list
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get bookingViewDetails;

  /// Detail status banner when Requested/Draft and paid
  ///
  /// In en, this message translates to:
  /// **'Waiting for company approval'**
  String get bookingAwaitingCompanyApproval;

  /// Detail status banner when Requested/Draft and unpaid
  ///
  /// In en, this message translates to:
  /// **'Waiting for provider confirmation'**
  String get bookingWaitingProviderConfirmation;

  /// Hint when Accept is disabled because unpaid
  ///
  /// In en, this message translates to:
  /// **'You can accept only after the client pays.'**
  String get bookingCannotAcceptUnpaid;

  /// Business booking detail mark complete button
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get businessBookingComplete;

  /// Snackbar after business marks booking complete
  ///
  /// In en, this message translates to:
  /// **'Booking completed'**
  String get businessBookingCompletedSnackbar;

  /// Hint when Complete is disabled before session start
  ///
  /// In en, this message translates to:
  /// **'Mark complete is available after the session start time.'**
  String get businessBookingCompleteBeforeStart;

  /// Business booking detail open chat with customer
  ///
  /// In en, this message translates to:
  /// **'Message customer'**
  String get businessBookingMessage;

  /// Customer booking detail open chat with business
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get bookingMessage;

  /// Business banner when they proposed a reschedule
  ///
  /// In en, this message translates to:
  /// **'Waiting for the client to respond to your reschedule proposal.'**
  String get bookingReschedulePendingClient;

  /// Client banner when business proposed a reschedule
  ///
  /// In en, this message translates to:
  /// **'The business proposed a new time. Accept or decline below.'**
  String get bookingReschedulePendingBusiness;

  /// Client banner when business proposed reschedule on unpaid booking
  ///
  /// In en, this message translates to:
  /// **'Pay to confirm the new time, or decline the proposal.'**
  String get bookingReschedulePayFirst;

  /// Snackbar after client proposes a reschedule
  ///
  /// In en, this message translates to:
  /// **'Reschedule proposed'**
  String get bookingRescheduleProposed;

  /// Profile security 2FA title
  ///
  /// In en, this message translates to:
  /// **'Email sign-in verification'**
  String get profileSecurityTwoFactorTitle;

  /// Profile security 2FA explanation
  ///
  /// In en, this message translates to:
  /// **'A one-time code is sent to your email when you sign in with a password.'**
  String get profileSecurityTwoFactorBody;

  /// Confirm disabling 2FA
  ///
  /// In en, this message translates to:
  /// **'Turn off email verification for password sign-in?'**
  String get profileSecurityTwoFactorDisableConfirm;

  /// Snackbar after enabling 2FA
  ///
  /// In en, this message translates to:
  /// **'Email verification is on'**
  String get profileSecurityTwoFactorOn;

  /// Snackbar after disabling 2FA
  ///
  /// In en, this message translates to:
  /// **'Email verification is off'**
  String get profileSecurityTwoFactorOff;

  /// Accept pending reschedule proposal
  ///
  /// In en, this message translates to:
  /// **'Accept reschedule'**
  String get bookingAcceptReschedule;

  /// Decline pending reschedule proposal
  ///
  /// In en, this message translates to:
  /// **'Decline reschedule'**
  String get bookingDeclineReschedule;

  /// Snackbar after accepting reschedule
  ///
  /// In en, this message translates to:
  /// **'Reschedule accepted'**
  String get bookingRescheduleAccepted;

  /// Snackbar after declining reschedule
  ///
  /// In en, this message translates to:
  /// **'Reschedule declined'**
  String get bookingRescheduleDeclined;

  /// Heading above open time slot chips
  ///
  /// In en, this message translates to:
  /// **'Available time'**
  String get bookingAvailableTime;

  /// Shown while open-slots are fetched for a day
  ///
  /// In en, this message translates to:
  /// **'Loading available times…'**
  String get bookingSlotsLoading;

  /// Empty state when open-slots returns no chips
  ///
  /// In en, this message translates to:
  /// **'No times available for this day. Pick another date.'**
  String get bookingNoSlotsForDay;

  /// Title of open-slots reschedule sheet
  ///
  /// In en, this message translates to:
  /// **'Choose a new time'**
  String get bookingReschedulePickTitle;

  /// Confirm button on open-slots reschedule sheet
  ///
  /// In en, this message translates to:
  /// **'Propose this time'**
  String get bookingRescheduleConfirmSlot;

  /// Label for multi-select of service location types
  ///
  /// In en, this message translates to:
  /// **'Accepted venues'**
  String get businessServiceAcceptedVenues;

  /// Hint that price min/max come from variants
  ///
  /// In en, this message translates to:
  /// **'Price range is set from options below.'**
  String get businessServicePriceFromOptions;

  /// Label for primary service photo on create/edit
  ///
  /// In en, this message translates to:
  /// **'Service image'**
  String get businessServiceImageLabel;

  /// Empty state under service image picker
  ///
  /// In en, this message translates to:
  /// **'Add a cover photo for this service'**
  String get businessServiceImageHint;

  /// Button to pick service cover image
  ///
  /// In en, this message translates to:
  /// **'Choose photo'**
  String get businessServiceImagePick;

  /// Validation when creating/editing without a cover image
  ///
  /// In en, this message translates to:
  /// **'A service image is required'**
  String get businessServiceImageRequired;

  /// Error when Flutter web cannot upload service media
  ///
  /// In en, this message translates to:
  /// **'Image upload is not supported on web in this build'**
  String get businessServiceImageWebUnsupported;

  /// Heading above feature choice cards on service form
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get businessServiceFeaturesSection;

  /// About page app bar title
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// Profile menu link to About Vaxiil
  ///
  /// In en, this message translates to:
  /// **'About Vaxiil'**
  String get aboutVaxiil;

  /// About page: what Vaxiil is
  ///
  /// In en, this message translates to:
  /// **'Vaxiil helps you discover and book wellness and related services—like massage, therapy, beauty, and space rentals—from verified local businesses, with privacy-minded tools so you stay in control of what you share.'**
  String get aboutWhat;

  /// About page: how Vaxiil works
  ///
  /// In en, this message translates to:
  /// **'How it works: browse services and venues, pick a time that suits you, pay securely (including mobile money or wallet where available), then get reminders and message the business. If you offer services, the business area lets you manage listings, bookings, and payouts.'**
  String get aboutHow;

  /// About page: origin story
  ///
  /// In en, this message translates to:
  /// **'Vaxiil was built by Congolese creators while they lived in Bujumbura.'**
  String get aboutOrigin;

  /// About page: operator and contact
  ///
  /// In en, this message translates to:
  /// **'Vaxiil is operated by BAP IMAGINE SPRL. Contact: info@bapimagine.com'**
  String get aboutOwner;

  /// About page version row label
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get aboutVersion;

  /// About page link to terms
  ///
  /// In en, this message translates to:
  /// **'Terms of service'**
  String get aboutTerms;

  /// About page link to privacy policy
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get aboutPrivacy;

  /// About page CTA to open platform support chat
  ///
  /// In en, this message translates to:
  /// **'Chat with Vaxiil support'**
  String get aboutContactChat;

  /// Notifications inbox screen title
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// Notifications inbox subtitle
  ///
  /// In en, this message translates to:
  /// **'Stay updated with your wellness journey'**
  String get notificationsSubtitle;

  /// Mark all notifications as read
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get notificationsMarkAllRead;

  /// Mark a single notification as read
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get notificationsMarkRead;

  /// Open booking from a notification
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get notificationsViewDetails;

  /// Empty notifications inbox message
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up! No new notifications.'**
  String get notificationsEmpty;

  /// Empty notifications CTA to discover
  ///
  /// In en, this message translates to:
  /// **'Explore services'**
  String get notificationsEmptyCta;

  /// Notifications list load error title
  ///
  /// In en, this message translates to:
  /// **'Could not load notifications'**
  String get notificationsLoadError;

  /// Retry loading notifications
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get notificationsRetry;

  /// Notifications group: today
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get notificationsToday;

  /// Notifications group: yesterday
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get notificationsYesterday;

  /// Notifications group: earlier
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get notificationsEarlier;

  /// Profile settings link to notifications inbox
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get profileNotificationsInbox;

  /// No description provided for @messagesInboxTitle.
  ///
  /// In en, this message translates to:
  /// **'Pulse Inbox'**
  String get messagesInboxTitle;

  /// No description provided for @messagesInboxSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your wellness dialogue, curated.'**
  String get messagesInboxSubtitle;

  /// No description provided for @messagesComposeAria.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation'**
  String get messagesComposeAria;

  /// No description provided for @messagesTabConversations.
  ///
  /// In en, this message translates to:
  /// **'Conversations'**
  String get messagesTabConversations;

  /// No description provided for @messagesTabInvitations.
  ///
  /// In en, this message translates to:
  /// **'Invitations'**
  String get messagesTabInvitations;

  /// No description provided for @messagesNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get messagesNew;

  /// No description provided for @messagesEmptyConversations.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet. Invite someone to get started.'**
  String get messagesEmptyConversations;

  /// No description provided for @messagesEmptyInvites.
  ///
  /// In en, this message translates to:
  /// **'No invitations right now.'**
  String get messagesEmptyInvites;

  /// No description provided for @messagesInvitePrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'They cannot see whether you are on Vaxiil until you accept.'**
  String get messagesInvitePrivacyNote;

  /// No description provided for @messagesAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get messagesAccept;

  /// No description provided for @messagesDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get messagesDecline;

  /// No description provided for @messagesSomeone.
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get messagesSomeone;

  /// No description provided for @messagesInviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation'**
  String get messagesInviteTitle;

  /// No description provided for @messagesInviteLede.
  ///
  /// In en, this message translates to:
  /// **'Coordinate without sharing contact details. Use email, phone, or a trust alias.'**
  String get messagesInviteLede;

  /// No description provided for @messagesInvitePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Email, phone or alias…'**
  String get messagesInvitePlaceholder;

  /// No description provided for @messagesSendInvite.
  ///
  /// In en, this message translates to:
  /// **'Send invitation'**
  String get messagesSendInvite;

  /// No description provided for @messagesInvitePrivacyCard.
  ///
  /// In en, this message translates to:
  /// **'If this person is on Vaxiil, an invitation will be sent. They must accept before you can message.'**
  String get messagesInvitePrivacyCard;

  /// No description provided for @messagesMyTrustAlias.
  ///
  /// In en, this message translates to:
  /// **'My trust alias'**
  String get messagesMyTrustAlias;

  /// No description provided for @messagesBackToInbox.
  ///
  /// In en, this message translates to:
  /// **'Back to inbox'**
  String get messagesBackToInbox;

  /// No description provided for @messagesThreadFallback.
  ///
  /// In en, this message translates to:
  /// **'Conversation'**
  String get messagesThreadFallback;

  /// Open booking detail from a booking conversation title
  ///
  /// In en, this message translates to:
  /// **'View booking'**
  String get messagesViewBooking;

  /// No description provided for @messagesBlock.
  ///
  /// In en, this message translates to:
  /// **'Block conversation'**
  String get messagesBlock;

  /// No description provided for @messagesUnblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get messagesUnblock;

  /// No description provided for @messagesBlockedBanner.
  ///
  /// In en, this message translates to:
  /// **'You have blocked this conversation. Unblock to send messages.'**
  String get messagesBlockedBanner;

  /// No description provided for @messagesPrivacyChip.
  ///
  /// In en, this message translates to:
  /// **'This conversation uses trust aliases for your privacy.'**
  String get messagesPrivacyChip;

  /// No description provided for @messagesComposerPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Type a message…'**
  String get messagesComposerPlaceholder;

  /// No description provided for @messagesBusinessInboxTitle.
  ///
  /// In en, this message translates to:
  /// **'Business inbox'**
  String get messagesBusinessInboxTitle;

  /// No description provided for @messagesBusinessInboxSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Conversations for this organization.'**
  String get messagesBusinessInboxSubtitle;

  /// No description provided for @messagesBusinessEmpty.
  ///
  /// In en, this message translates to:
  /// **'No organization conversations yet.'**
  String get messagesBusinessEmpty;

  /// No description provided for @notificationsBusinessTitle.
  ///
  /// In en, this message translates to:
  /// **'Business notifications'**
  String get notificationsBusinessTitle;

  /// No description provided for @notificationsBusinessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Updates for this organization'**
  String get notificationsBusinessSubtitle;

  /// No description provided for @notificationsStaffTitle.
  ///
  /// In en, this message translates to:
  /// **'Staff notifications'**
  String get notificationsStaffTitle;

  /// No description provided for @notificationsBusinessEmptyCta.
  ///
  /// In en, this message translates to:
  /// **'Back to hub'**
  String get notificationsBusinessEmptyCta;

  /// No description provided for @businessHubMoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Admin quick actions'**
  String get businessHubMoreTitle;

  /// No description provided for @businessHubSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get businessHubSettings;

  /// No description provided for @businessHubSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure organization'**
  String get businessHubSettingsSubtitle;

  /// No description provided for @businessHubAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get businessHubAnalytics;

  /// No description provided for @businessHubAnalyticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bookings and revenue'**
  String get businessHubAnalyticsSubtitle;

  /// No description provided for @businessHubMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get businessHubMessages;

  /// No description provided for @businessHubMessagesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Organization inbox'**
  String get businessHubMessagesSubtitle;

  /// No description provided for @businessHubNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get businessHubNotifications;

  /// No description provided for @businessHubNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Organization alerts'**
  String get businessHubNotificationsSubtitle;

  /// No description provided for @cityLabel.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get cityLabel;

  /// No description provided for @citySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search city…'**
  String get citySearchHint;

  /// No description provided for @citySelectCountryFirst.
  ///
  /// In en, this message translates to:
  /// **'Select a country first'**
  String get citySelectCountryFirst;

  /// No description provided for @cityRequired.
  ///
  /// In en, this message translates to:
  /// **'Select a city'**
  String get cityRequired;

  /// No description provided for @streetAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Street address'**
  String get streetAddressLabel;

  /// No description provided for @postalCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Postal code'**
  String get postalCodeLabel;

  /// No description provided for @countryLabel.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get countryLabel;

  /// No description provided for @latitudeLabel.
  ///
  /// In en, this message translates to:
  /// **'Latitude (optional)'**
  String get latitudeLabel;

  /// No description provided for @longitudeLabel.
  ///
  /// In en, this message translates to:
  /// **'Longitude (optional)'**
  String get longitudeLabel;

  /// No description provided for @businessLocationDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Business location'**
  String get businessLocationDialogTitle;

  /// No description provided for @doneLabel.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneLabel;

  /// No description provided for @editProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfileTitle;

  /// No description provided for @firstNameLabel.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get firstNameLabel;

  /// No description provided for @lastNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get lastNameLabel;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phoneLabel;

  /// No description provided for @dateOfBirthLabel.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get dateOfBirthLabel;

  /// No description provided for @sexLabel.
  ///
  /// In en, this message translates to:
  /// **'Sex'**
  String get sexLabel;

  /// No description provided for @sexFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get sexFemale;

  /// No description provided for @sexMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get sexMale;

  /// No description provided for @sexOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get sexOther;

  /// No description provided for @sexPreferNot.
  ///
  /// In en, this message translates to:
  /// **'Prefer not to say'**
  String get sexPreferNot;

  /// No description provided for @defaultCountryLabel.
  ///
  /// In en, this message translates to:
  /// **'Default country'**
  String get defaultCountryLabel;

  /// No description provided for @defaultCountryHint.
  ///
  /// In en, this message translates to:
  /// **'Used to filter discovery'**
  String get defaultCountryHint;

  /// No description provided for @defaultCountryNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get defaultCountryNone;

  /// No description provided for @loadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loadingLabel;

  /// No description provided for @saveLabel.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveLabel;

  /// No description provided for @countryFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get countryFilterLabel;

  /// No description provided for @countryFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All countries'**
  String get countryFilterAll;

  /// No description provided for @countrySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search countries'**
  String get countrySearchHint;

  /// No description provided for @venuesTitle.
  ///
  /// In en, this message translates to:
  /// **'Trusted venues'**
  String get venuesTitle;

  /// No description provided for @venuesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Verified companies in your country'**
  String get venuesSubtitle;

  /// No description provided for @venuesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No venues in this country yet.'**
  String get venuesEmpty;

  /// No description provided for @venuesLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get venuesLoading;

  /// No description provided for @venuesLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get venuesLoadMore;

  /// No description provided for @venuesViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get venuesViewAll;

  /// No description provided for @trustedVenuesSection.
  ///
  /// In en, this message translates to:
  /// **'Trusted venues'**
  String get trustedVenuesSection;

  /// No description provided for @inscriptionFee.
  ///
  /// In en, this message translates to:
  /// **'Verification fee (one-time)'**
  String get inscriptionFee;

  /// No description provided for @inscriptionFeeHint.
  ///
  /// In en, this message translates to:
  /// **'One-time fee for security and identity verification. It helps keep the platform secure with real verified people and businesses.'**
  String get inscriptionFeeHint;

  /// No description provided for @businessHubSettlement.
  ///
  /// In en, this message translates to:
  /// **'Settlement'**
  String get businessHubSettlement;

  /// No description provided for @businessHubSettlementSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Balances, payout accounts, and requests'**
  String get businessHubSettlementSubtitle;

  /// No description provided for @businessSettlementTitle.
  ///
  /// In en, this message translates to:
  /// **'Settlement'**
  String get businessSettlementTitle;

  /// No description provided for @businessSettlementLede.
  ///
  /// In en, this message translates to:
  /// **'Configure payout destinations, periodicity, and request withdrawals.'**
  String get businessSettlementLede;

  /// No description provided for @businessSettlementBalance.
  ///
  /// In en, this message translates to:
  /// **'Available balance'**
  String get businessSettlementBalance;

  /// No description provided for @businessSettlementLedgerBalance.
  ///
  /// In en, this message translates to:
  /// **'ledger'**
  String get businessSettlementLedgerBalance;

  /// No description provided for @businessSettlementNoBalance.
  ///
  /// In en, this message translates to:
  /// **'No revenue balance yet.'**
  String get businessSettlementNoBalance;

  /// No description provided for @businessSettlementSettings.
  ///
  /// In en, this message translates to:
  /// **'Settlement rules'**
  String get businessSettlementSettings;

  /// No description provided for @businessSettlementPeriodicity.
  ///
  /// In en, this message translates to:
  /// **'Periodicity'**
  String get businessSettlementPeriodicity;

  /// No description provided for @businessSettlementWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get businessSettlementWeekly;

  /// No description provided for @businessSettlementBiweekly.
  ///
  /// In en, this message translates to:
  /// **'Biweekly'**
  String get businessSettlementBiweekly;

  /// No description provided for @businessSettlementMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get businessSettlementMonthly;

  /// No description provided for @businessSettlementManual.
  ///
  /// In en, this message translates to:
  /// **'Manual only'**
  String get businessSettlementManual;

  /// No description provided for @businessSettlementMinimum.
  ///
  /// In en, this message translates to:
  /// **'Minimum amount'**
  String get businessSettlementMinimum;

  /// No description provided for @businessSettlementMinimumFloor.
  ///
  /// In en, this message translates to:
  /// **'Platform floor'**
  String get businessSettlementMinimumFloor;

  /// No description provided for @businessSettlementAccounts.
  ///
  /// In en, this message translates to:
  /// **'Payout accounts'**
  String get businessSettlementAccounts;

  /// No description provided for @businessSettlementNoAccounts.
  ///
  /// In en, this message translates to:
  /// **'No payout accounts yet.'**
  String get businessSettlementNoAccounts;

  /// No description provided for @businessSettlementAddAccount.
  ///
  /// In en, this message translates to:
  /// **'Add payout account'**
  String get businessSettlementAddAccount;

  /// No description provided for @businessSettlementEmail.
  ///
  /// In en, this message translates to:
  /// **'Account number / IBAN / phone / email'**
  String get businessSettlementEmail;

  /// No description provided for @businessSettlementHolder.
  ///
  /// In en, this message translates to:
  /// **'Account name'**
  String get businessSettlementHolder;

  /// No description provided for @businessSettlementManualRequest.
  ///
  /// In en, this message translates to:
  /// **'Request settlement'**
  String get businessSettlementManualRequest;

  /// No description provided for @businessSettlementRequest.
  ///
  /// In en, this message translates to:
  /// **'Submit request'**
  String get businessSettlementRequest;

  /// No description provided for @businessSettlementHistory.
  ///
  /// In en, this message translates to:
  /// **'Request history'**
  String get businessSettlementHistory;

  /// No description provided for @businessSettlementNoRequests.
  ///
  /// In en, this message translates to:
  /// **'No settlement requests yet.'**
  String get businessSettlementNoRequests;

  /// Payment history page title
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactionsTitle;

  /// Payment history page subtitle
  ///
  /// In en, this message translates to:
  /// **'Booking payments, store credit top-ups, and refunds.'**
  String get transactionsSubtitle;

  /// Empty state for payment history
  ///
  /// In en, this message translates to:
  /// **'You have no transactions yet.'**
  String get transactionsEmpty;

  /// Load more transactions
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get transactionsLoadMore;

  /// Loading more transactions
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get transactionsLoading;

  /// Retry loading transactions
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get transactionsRetry;

  /// Link label on booking payment rows
  ///
  /// In en, this message translates to:
  /// **'View booking'**
  String get transactionsViewBooking;

  /// Aria / tooltip for refresh transaction status button
  ///
  /// In en, this message translates to:
  /// **'Refresh status'**
  String get transactionsRefreshStatus;

  /// SnackBar when status refresh fails
  ///
  /// In en, this message translates to:
  /// **'Could not refresh status'**
  String get transactionsRefreshFailed;

  /// All statuses filter
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get transactionsFilterAll;

  /// Succeeded status filter
  ///
  /// In en, this message translates to:
  /// **'Succeeded'**
  String get transactionsStatusSucceeded;

  /// Pending status filter
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get transactionsStatusPending;

  /// Processing status filter
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get transactionsStatusProcessing;

  /// Failed status filter
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get transactionsStatusFailed;

  /// Profile settings row for payment history
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get profileTransactions;
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
