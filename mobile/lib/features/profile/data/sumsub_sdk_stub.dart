Future<void> launchSumsubSdk({
  required String accessToken,
  required Future<String> Function() onTokenExpiration,
}) =>
    throw UnsupportedError(
      'Sumsub native SDK is not available on this platform',
    );
