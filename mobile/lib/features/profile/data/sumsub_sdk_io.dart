import 'package:flutter/material.dart';
import 'package:flutter_idensic_mobile_sdk_plugin/flutter_idensic_mobile_sdk_plugin.dart';

Future<void> launchSumsubSdk({
  required String accessToken,
  required Future<String> Function() onTokenExpiration,
}) async {
  final snsMobileSDK = SNSMobileSDK.init(accessToken, onTokenExpiration)
      .withHandlers(
        onStatusChanged: (newStatus, prevStatus) {
          debugPrint('Sumsub SDK status: $prevStatus -> $newStatus');
        },
      )
      .withLocale(const Locale('en'))
      .build();
  await snsMobileSDK.launch();
}
