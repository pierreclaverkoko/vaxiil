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
  String get emailVerifyTitle => 'Verify your email';

  @override
  String emailVerifyLede(String email) {
    return 'Enter the code we sent to $email to continue.';
  }

  @override
  String get emailVerifyCode => 'Verification code';

  @override
  String get emailVerifyCodeRequired => 'Enter the verification code.';

  @override
  String get emailVerifySubmit => 'Verify email';

  @override
  String get emailVerifySubmitting => 'Verifying…';

  @override
  String get emailVerifyResend => 'Resend code';

  @override
  String get emailVerifySent => 'A verification code was sent to your email.';

  @override
  String get loginOtpCode => 'Verification code';

  @override
  String get loginOtpRequired => 'Enter the verification code.';

  @override
  String get loginVerifyOtp => 'Verify and sign in';

  @override
  String get loginOtpBack => 'Back to sign in';

  @override
  String get turnstileRequired => 'Please complete the security check.';

  @override
  String get forgotPasswordTitle => 'Reset password';

  @override
  String get forgotPasswordLede => 'We will email you a one-time code to set a new password.';

  @override
  String get forgotPasswordEmail => 'Email Address';

  @override
  String get forgotPasswordEmailRequired => 'Enter a valid email.';

  @override
  String get forgotPasswordSendCode => 'Send code';

  @override
  String get forgotPasswordReset => 'Reset password';

  @override
  String get forgotPasswordNewPassword => 'New password';

  @override
  String get forgotPasswordPasswordShort => 'At least 8 characters';

  @override
  String get forgotPasswordCodeSent => 'If an account exists for this email, a code was sent.';

  @override
  String get forgotPasswordDone => 'Password reset complete. You can sign in now.';

  @override
  String get forgotPasswordBackToLogin => 'Back to login';

  @override
  String get forgotPasswordMissingChallenge => 'Request a new code first.';

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
  String get businessServiceImageLabel => 'Service image';

  @override
  String get businessServiceImageHint => 'Add a cover photo for this service';

  @override
  String get businessServiceImagePick => 'Choose photo';

  @override
  String get businessServiceImageRequired => 'A service image is required';

  @override
  String get businessServiceImageWebUnsupported => 'Image upload is not supported on web in this build';

  @override
  String get businessServiceFeaturesSection => 'Features';

  @override
  String get aboutContactChat => 'Chat with Vaxiil support';

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

  @override
  String get messagesInboxTitle => 'Pulse Inbox';

  @override
  String get messagesInboxSubtitle => 'Your wellness dialogue, curated.';

  @override
  String get messagesComposeAria => 'Start a conversation';

  @override
  String get messagesTabConversations => 'Conversations';

  @override
  String get messagesTabInvitations => 'Invitations';

  @override
  String get messagesNew => 'New';

  @override
  String get messagesEmptyConversations => 'No conversations yet. Invite someone to get started.';

  @override
  String get messagesEmptyInvites => 'No invitations right now.';

  @override
  String get messagesInvitePrivacyNote => 'They cannot see whether you are on Vaxiil until you accept.';

  @override
  String get messagesAccept => 'Accept';

  @override
  String get messagesDecline => 'Decline';

  @override
  String get messagesSomeone => 'Someone';

  @override
  String get messagesInviteTitle => 'Start a conversation';

  @override
  String get messagesInviteLede => 'Coordinate without sharing contact details. Use email, phone, or a trust alias.';

  @override
  String get messagesInvitePlaceholder => 'Email, phone or alias…';

  @override
  String get messagesSendInvite => 'Send invitation';

  @override
  String get messagesInvitePrivacyCard => 'If this person is on Vaxiil, an invitation will be sent. They must accept before you can message.';

  @override
  String get messagesMyTrustAlias => 'My trust alias';

  @override
  String get messagesBackToInbox => 'Back to inbox';

  @override
  String get messagesThreadFallback => 'Conversation';

  @override
  String get messagesBlock => 'Block conversation';

  @override
  String get messagesUnblock => 'Unblock';

  @override
  String get messagesBlockedBanner => 'You have blocked this conversation. Unblock to send messages.';

  @override
  String get messagesPrivacyChip => 'This conversation uses trust aliases for your privacy.';

  @override
  String get messagesComposerPlaceholder => 'Type a message…';

  @override
  String get messagesBusinessInboxTitle => 'Business inbox';

  @override
  String get messagesBusinessInboxSubtitle => 'Conversations for this organization.';

  @override
  String get messagesBusinessEmpty => 'No organization conversations yet.';

  @override
  String get notificationsBusinessTitle => 'Business notifications';

  @override
  String get notificationsBusinessSubtitle => 'Updates for this organization';

  @override
  String get notificationsStaffTitle => 'Staff notifications';

  @override
  String get notificationsBusinessEmptyCta => 'Back to hub';

  @override
  String get businessHubMoreTitle => 'Admin quick actions';

  @override
  String get businessHubSettings => 'Settings';

  @override
  String get businessHubSettingsSubtitle => 'Configure organization';

  @override
  String get businessHubAnalytics => 'Analytics';

  @override
  String get businessHubAnalyticsSubtitle => 'Bookings and revenue';

  @override
  String get businessHubMessages => 'Messages';

  @override
  String get businessHubMessagesSubtitle => 'Organization inbox';

  @override
  String get businessHubNotifications => 'Notifications';

  @override
  String get businessHubNotificationsSubtitle => 'Organization alerts';

  @override
  String get cityLabel => 'City';

  @override
  String get citySearchHint => 'Search city…';

  @override
  String get citySelectCountryFirst => 'Select a country first';

  @override
  String get cityRequired => 'Select a city';

  @override
  String get streetAddressLabel => 'Street address';

  @override
  String get postalCodeLabel => 'Postal code';

  @override
  String get countryLabel => 'Country';

  @override
  String get latitudeLabel => 'Latitude (optional)';

  @override
  String get longitudeLabel => 'Longitude (optional)';

  @override
  String get businessLocationDialogTitle => 'Business location';

  @override
  String get doneLabel => 'Done';

  @override
  String get editProfileTitle => 'Edit profile';

  @override
  String get firstNameLabel => 'First name';

  @override
  String get lastNameLabel => 'Last name';

  @override
  String get phoneLabel => 'Phone';

  @override
  String get dateOfBirthLabel => 'Date of birth';

  @override
  String get sexLabel => 'Sex';

  @override
  String get sexFemale => 'Female';

  @override
  String get sexMale => 'Male';

  @override
  String get sexOther => 'Other';

  @override
  String get sexPreferNot => 'Prefer not to say';

  @override
  String get defaultCountryLabel => 'Default country';

  @override
  String get defaultCountryHint => 'Used to filter discovery';

  @override
  String get defaultCountryNone => 'None';

  @override
  String get loadingLabel => 'Loading…';

  @override
  String get saveLabel => 'Save';

  @override
  String get countryFilterLabel => 'Country';

  @override
  String get countryFilterAll => 'All countries';
}
