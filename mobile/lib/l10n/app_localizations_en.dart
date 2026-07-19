import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Vaxiil';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageSubtitle => 'Choose the language for the app and API messages.';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageFrench => 'French';

  @override
  String get languageSaved => 'Language updated';

  @override
  String get loginOtpLede => 'Enter the verification code sent to your email.';

  @override
  String get loginOtpCode => 'Verification code';

  @override
  String get loginOtpRequired => 'Enter the verification code.';

  @override
  String get loginVerifyOtp => 'Verify and sign in';

  @override
  String get loginOtpBack => 'Back to sign in';

  @override
  String get escrowBalanceTitle => 'Escrow balance';

  @override
  String get escrowBalanceHint => 'Store credit from cancellations or top-ups. Apply it at checkout on your next booking.';

  @override
  String get escrowTopUp => 'Add funds';

  @override
  String get escrowTopUpAmount => 'Amount to add';

  @override
  String get escrowTopUpSubmit => 'Continue to payment';

  @override
  String get escrowTopUpHint => 'Add funds securely to your escrow balance.';

  @override
  String get payUseEscrowTitle => 'Use escrow credit?';

  @override
  String payUseEscrowBody(String balance, String currency) {
    return 'You have $balance $currency in escrow. Apply it to this payment?';
  }

  @override
  String get payEscrowApplied => 'Escrow applied';

  @override
  String get payCardAmount => 'Amount to pay now';

  @override
  String get payFullyPaidEscrow => 'Paid with escrow credit.';

  @override
  String get payUseEscrowYes => 'Yes, use credit';

  @override
  String get payUseEscrowNo => 'No';

  @override
  String bookingCancelledEscrowCredit(String amount, String currency) {
    return 'Booking cancelled. $amount $currency credited to escrow.';
  }

  @override
  String get businessBookingVenue => 'Venue';

  @override
  String get businessBookingSpecialRequests => 'Special requests';

  @override
  String get kycRequiredForBooking => 'Verify your identity before booking.';
}
