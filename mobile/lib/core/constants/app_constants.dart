import 'package:flutter/material.dart';

class AppConstants {
  // App Information
  static const String appName = 'Vaxiil';
  static const String appVersion = '1.0.0';

  /// Support / concierge contact (mailto and copy-to-clipboard).
  static const String supportEmail = 'support@vaxiil.com';
  static const String supportPhone = '+1-555-0100';
  static const String authRegenerateAliasPath = 'auth/regenerate-alias/';

  // API Configuration
  static const String baseUrl = 'http://localhost:9091';
  static const String apiVersion = 'v1';

  /// Must end with `/` so Dio resolves relative paths as `.../api/v1/auth/...` not `.../api/v1auth/...`.
  static const String apiBaseUrl = '$baseUrl/api/$apiVersion/';

  // API Endpoints (relative to [apiBaseUrl], no leading slash)
  static const String authEndpoint = 'auth';
  static const String authLoginPath = 'auth/login/';
  static const String authLoginVerifyOtpPath = 'auth/login/verify-otp/';
  static const String authOtpSendPath = 'auth/otp/send/';
  static const String authPasswordChangePath = 'auth/password/change/';
  static const String authPasswordResetRequestPath =
      'auth/password/reset/request/';
  static const String authPasswordResetConfirmPath =
      'auth/password/reset/confirm/';
  static const String authRegisterPath = 'auth/register/';
  static const String authLogoutPath = 'auth/logout/';
  static const String authTokenRefreshPath = 'auth/token/refresh/';
  static const String authProfilePath = 'auth/profile/';
  static const String authGooglePath = 'auth/google/';
  static const String authAvatarPath = 'auth/avatar/';
  static const String authVerifyPath = 'auth/verify/';
  static const String authSumsubAccessTokenPath =
      'auth/kyc/sumsub/access-token/';
  static const String authSumsubWebsdkLinkPath = 'auth/kyc/sumsub/websdk-link/';
  static const String authSumsubReturnPath = 'auth/kyc/sumsub/return/';
  static const String authGenerateAliasPath = 'auth/generate-alias/';
  static const String authMetadataPath = 'auth/metadata/';
  static const String authAcceptLegalPath = 'auth/accept-legal/';
  static const String authEmailVerifySendPath = 'auth/email/verify/send/';
  static const String authEmailVerifyPath = 'auth/email/verify/';
  static String legalDocumentPath(String documentType) => 'legal/$documentType/';
  static const String organizationsPath = 'organizations/';

  /// Aggregate stats across the user’s organizations (`GET organizations/mine-summary/`).
  static const String organizationsMineSummaryPath =
      'organizations/mine-summary/';

  /// Verified venues for home discovery (`GET organizations/discovery/`).
  static const String organizationsDiscoveryPath = 'organizations/discovery/';
  static const String organizationTypesPath = 'organizations/types/';
  static const String organizationCountriesPath = 'organizations/countries/';
  static const String organizationCitiesPath = 'organizations/cities/';

  static String organizationAddressesPath(String organizationId) =>
      'organizations/$organizationId/addresses/';

  static String organizationAddressPath(
    String organizationId,
    String addressId,
  ) =>
      'organizations/$organizationId/addresses/$addressId/';

  /// Relative to [apiBaseUrl]. Authenticated list of service categories (Heroicon names).
  static const String serviceCategoriesPath = 'services/categories/';

  /// Relative to [apiBaseUrl]. Paginated service catalog (search, filters).
  static const String serviceCatalogPath = 'services/';

  /// Open appointment slots for a calendar day:
  /// `GET services/{id}/open-slots/?date=YYYY-MM-DD`
  static String serviceOpenSlotsPath(String serviceId) =>
      '${serviceCatalogPath}$serviceId/open-slots/';

  /// Subcategories for provider forms.
  static const String serviceSubcategoriesPath = 'services/subcategories/';

  /// Global service features (amenities, requirements).
  static const String serviceFeaturesPath = 'services/features/';

  /// Org-scoped services: `organizations/{id}/services/`
  static String organizationServicesPath(String organizationId) =>
      'organizations/$organizationId/services/';

  static String organizationServiceMediaPath(
    String organizationId,
    String serviceId,
  ) =>
      '${organizationServicesPath(organizationId)}$serviceId/media/';

  /// Bookings CRUD: `bookings/`
  static const String bookingsPath = 'bookings/';
  static String bookingConfirmPath(String bookingId) =>
      '${bookingsPath}$bookingId/confirm/';
  static String bookingRejectPath(String bookingId) =>
      '${bookingsPath}$bookingId/reject/';
  static String bookingCompletePath(String bookingId) =>
      '${bookingsPath}$bookingId/complete/';
  static String organizationTeamPath(String organizationId) =>
      'organizations/$organizationId/team/';
  static String organizationTeamInvitePath(String organizationId) =>
      '${organizationTeamPath(organizationId)}invite/';
  static String organizationTeamMembershipPath(
    String organizationId,
    String membershipId,
  ) =>
      '${organizationTeamPath(organizationId)}$membershipId/';

  /// In-app notifications: `notifications/`
  static const String notificationsPath = 'notifications/';
  static String notificationMarkReadPath(String id) =>
      '${notificationsPath}$id/mark-read/';
  static const String notificationsMarkAllReadPath =
      'notifications/mark-all-read/';

  /// Messaging
  static const bool messagesEnabled = true;
  static const String messagingInvitesPath = 'messaging/invites/';
  static const String messagingInvitesIncomingPath =
      'messaging/invites/incoming/';
  static String messagingInviteAcceptPath(String id) =>
      'messaging/invites/$id/accept/';
  static String messagingInviteDeclinePath(String id) =>
      'messaging/invites/$id/decline/';
  static const String messagingConversationsPath = 'messaging/conversations/';
  static String messagingConversationPath(String id) =>
      'messaging/conversations/$id/';
  static String messagingMessagesPath(String id) =>
      'messaging/conversations/$id/messages/';
  static String messagingBlockPath(String id) =>
      'messaging/conversations/$id/block/';
  static String messagingUnblockPath(String id) =>
      'messaging/conversations/$id/unblock/';
  static String messagingReadPath(String id) =>
      'messaging/conversations/$id/read/';
  static const String messagingPlatformSupportPath =
      'messaging/conversations/platform-support/';
  static const String notificationsUnreadCountPath =
      'notifications/unread-count/';

  /// Create hosted payment link for a booking.
  static String bookingPaymentLinkPath(String bookingId) =>
      'payments/bookings/$bookingId/payment-link/';

  /// User escrow (wallet) balances.
  static const String paymentWalletPath = 'payments/wallet/';

  /// Top up escrow via hosted checkout.
  static const String paymentWalletTopUpPath = 'payments/wallet/top-up/';

  /// Payment transaction status by merchant reference.
  static String paymentTransactionPath(String clientReference) =>
      'payments/transactions/$clientReference/';

  /// POST multipart KYB: `organizations/{id}/submit-verification/`
  static String organizationSubmitVerificationPath(String organizationId) =>
      'organizations/$organizationId/submit-verification/';

  static String organizationSettlementBalancePath(String organizationId) =>
      'organizations/$organizationId/settlement/balance/';

  static String organizationSettlementAccountsPath(String organizationId) =>
      'organizations/$organizationId/settlement/accounts/';

  static String organizationSettlementSettingsPath(String organizationId) =>
      'organizations/$organizationId/settlement/settings/';

  static String organizationSettlementRequestsPath(String organizationId) =>
      'organizations/$organizationId/settlement/requests/';

  static const String usersEndpoint = '/users';
  static const String organizationsEndpoint = '/organizations';
  static const String servicesEndpoint = '/services';
  static const String bookingsEndpoint = '/bookings';
  static const String paymentsEndpoint = '/payments';

  // Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userProfileKey = 'user_profile';
  static const String currentBusinessKey = 'current_business';
  static const String themeKey = 'theme_preference';
  static const String languageKey = 'language_preference';

  /// Client-only favorite service IDs (until favorites API exists).
  static const String favoriteServiceIdsStorageKey = 'favorite_service_ids';

  // App Settings
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Cache Settings
  static const Duration cacheExpiration = Duration(hours: 1);
  static const Duration imageCacheExpiration = Duration(days: 7);

  // UI Constants (soft theme — large radii)
  static const double defaultPadding = 16;
  static const double smallPadding = 8;
  static const double largePadding = 24;
  static const double borderRadius = 20;
  static const double smallBorderRadius = 12;
  static const double radiusCard = 24;
  static const double radiusPill = 999;

  // Animation Durations
  static const Duration fastAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration slowAnimation = Duration(milliseconds: 500);

  // File Size Limits
  static const int maxImageSize = 5 * 1024 * 1024; // 5MB
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB

  // Supported Image Formats
  static const List<String> supportedImageFormats = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
  ];

  // WebSocket Configuration
  static const String wsUrl = 'ws://10.120.159.104:9091/ws';

  // Map Configuration
  static const double defaultMapZoom = 14;
  static const double minMapZoom = 2;
  static const double maxMapZoom = 18;

  /// Google Maps SDK (embed + native). Set at build time, e.g.
  /// `flutter run --dart-define=GOOGLE_MAPS_API_KEY=your_key`.
  /// Android also reads `google.maps.api.key` from `local.properties`
  /// for the native SDK meta-data.
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  /// Cloudflare Turnstile site key (public). Override at build time with
  /// `--dart-define=TURNSTILE_SITE_KEY=...` if needed.
  static const String turnstileSiteKey = String.fromEnvironment(
    'TURNSTILE_SITE_KEY',
    defaultValue: '0x4AAAAAAD9kzYulPy5lqUue',
  );

  /// Origin for Sumsub WebSDK success/reject redirects in non-release builds
  /// (no trailing slash). Override with
  /// `--dart-define=KYC_REDIRECT_ORIGIN=https://your-tunnel.example`.
  /// Release builds always use [Uri.base.origin] (Flutter web).
  static const String kycRedirectOrigin = String.fromEnvironment(
    'KYC_REDIRECT_ORIGIN',
    defaultValue: '',
  );

  /// Resolved KYC redirect origin: dart-define in debug/profile, else page origin.
  static String resolveKycRedirectOrigin() {
    if (!bool.fromEnvironment('dart.vm.product')) {
      final fromEnv = kycRedirectOrigin.trim();
      if (fromEnv.isNotEmpty) {
        return fromEnv.replaceAll(RegExp(r'/+$'), '');
      }
    }
    final base = Uri.base;
    if (base.hasScheme &&
        (base.scheme == 'http' || base.scheme == 'https') &&
        base.hasAuthority) {
      return base.origin;
    }
    return '';
  }

  // Business Hours
  static const TimeOfDay defaultOpeningTime = TimeOfDay(hour: 9, minute: 0);
  static const TimeOfDay defaultClosingTime = TimeOfDay(hour: 17, minute: 0);

  // Booking Settings
  static const Duration minBookingDuration = Duration(minutes: 30);
  static const Duration maxBookingDuration = Duration(hours: 8);
  static const Duration bookingAdvanceTime = Duration(hours: 2);

  // Notification Settings
  static const Duration notificationShowTime = Duration(seconds: 4);
  static const int maxNotifications = 50;
}
