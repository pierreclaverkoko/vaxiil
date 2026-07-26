import 'sumsub_sdk_stub.dart'
    if (dart.library.io) 'sumsub_sdk_io.dart' as impl;

Future<void> launchSumsubSdk({
  required String accessToken,
  required Future<String> Function() onTokenExpiration,
}) =>
    impl.launchSumsubSdk(
      accessToken: accessToken,
      onTokenExpiration: onTokenExpiration,
    );
