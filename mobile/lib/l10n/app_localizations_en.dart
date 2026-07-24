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
  String get escrowBalanceTitle => 'Store credit';

  @override
  String get escrowBalanceHint => 'Store credit from cancellations or top-ups. Apply it at checkout on your next booking.';

  @override
  String get escrowTopUp => 'Add funds';

  @override
  String get escrowTopUpAmount => 'Amount to add';

  @override
  String get escrowTopUpSubmit => 'Continue to payment';

  @override
  String get escrowTopUpHint => 'Add funds securely to your store credit.';

  @override
  String get payUseEscrowTitle => 'Use store credit?';

  @override
  String payUseEscrowBody(String balance, String currency) {
    return 'You have $balance $currency in store credit. Apply it to this payment?';
  }

  @override
  String get payEscrowApplied => 'Store credit applied';

  @override
  String get payCardAmount => 'Amount to pay now';

  @override
  String get payFullyPaidEscrow => 'Paid with store credit.';

  @override
  String get payUseEscrowYes => 'Yes, use credit';

  @override
  String get payUseEscrowNo => 'No';

  @override
  String bookingCancelledEscrowCredit(String amount, String currency) {
    return 'Booking cancelled. $amount $currency credited to store credit.';
  }

  @override
  String get businessBookingVenue => 'Venue';

  @override
  String get businessBookingSpecialRequests => 'Special requests';

  @override
  String get kycRequiredForBooking => 'Verify your identity before booking.';

  @override
  String get bookingLocationTitle => 'Location';

  @override
  String get bookingLocationOffice => 'At venue';

  @override
  String get bookingLocationHome => 'At my home';

  @override
  String get bookingLocationVirtual => 'Virtual / online';

  @override
  String get bookingLocationMobile => 'Mobile service';

  @override
  String get businessBookingFeeBase => 'Service price';

  @override
  String get businessBookingFeePlatform => 'Platform fee';

  @override
  String get businessBookingFeeTotal => 'Total';

  @override
  String get businessBookingNetCaptured => 'Net captured';

  @override
  String get bookingPaidBadge => 'Paid';

  @override
  String get bookingCannotAcceptUnpaid => 'You can accept only after the client pays.';

  @override
  String get bookingReschedulePendingClient => 'Waiting for the client to respond to your reschedule proposal.';

  @override
  String get bookingReschedulePendingBusiness => 'The business proposed a new time. Accept or decline below.';

  @override
  String get bookingReschedulePayFirst => 'Pay to confirm the new time, or decline the proposal.';

  @override
  String get bookingRescheduleProposed => 'Reschedule proposed';

  @override
  String get profileSecurityTwoFactorTitle => 'Email sign-in verification';

  @override
  String get profileSecurityTwoFactorBody => 'A one-time code is sent to your email when you sign in with a password.';

  @override
  String get profileSecurityTwoFactorDisableConfirm => 'Turn off email verification for password sign-in?';

  @override
  String get profileSecurityTwoFactorOn => 'Email verification is on';

  @override
  String get profileSecurityTwoFactorOff => 'Email verification is off';

  @override
  String get bookingAcceptReschedule => 'Accept reschedule';

  @override
  String get bookingDeclineReschedule => 'Decline reschedule';

  @override
  String get bookingRescheduleAccepted => 'Reschedule accepted';

  @override
  String get bookingRescheduleDeclined => 'Reschedule declined';

  @override
  String get bookingAvailableTime => 'Available time';

  @override
  String get bookingSlotsLoading => 'Loading available times…';

  @override
  String get bookingNoSlotsForDay => 'No times available for this day. Pick another date.';

  @override
  String get bookingReschedulePickTitle => 'Choose a new time';

  @override
  String get bookingRescheduleConfirmSlot => 'Propose this time';

  @override
  String get businessServiceAcceptedVenues => 'Accepted venues';

  @override
  String get businessServicePriceFromOptions => 'Price range is set from options below.';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsSubtitle => 'Stay updated with your wellness journey';

  @override
  String get notificationsMarkAllRead => 'Mark all as read';

  @override
  String get notificationsMarkRead => 'Mark as read';

  @override
  String get notificationsViewDetails => 'View details';

  @override
  String get notificationsEmpty => 'You\'re all caught up! No new notifications.';

  @override
  String get notificationsEmptyCta => 'Explore services';

  @override
  String get notificationsLoadError => 'Could not load notifications';

  @override
  String get notificationsRetry => 'Retry';

  @override
  String get notificationsToday => 'Today';

  @override
  String get notificationsYesterday => 'Yesterday';

  @override
  String get notificationsEarlier => 'Earlier';

  @override
  String get profileNotificationsInbox => 'Notifications';
}
