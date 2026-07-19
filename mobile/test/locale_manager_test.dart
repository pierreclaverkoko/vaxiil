import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaxiil_mobile/core/locale/locale_manager.dart';
import 'package:vaxiil_mobile/core/network/interceptors/accept_language_interceptor.dart';
import 'package:vaxiil_mobile/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppLocalizations supports en and fr', () {
    expect(AppLocalizations.supportedLocales, contains(const Locale('en')));
    expect(AppLocalizations.supportedLocales, contains(const Locale('fr')));
  });

  test('AcceptLanguageInterceptor sets Accept-Language header', () async {
    final dio = Dio();
    dio.interceptors.add(AcceptLanguageInterceptor(LocaleManager()));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(
            options.headers['Accept-Language'],
            LocaleManager().languageCode,
          );
          handler.resolve(
            Response(requestOptions: options, statusCode: 200),
          );
        },
      ),
    );
    await dio.get<void>('/ping');
  });
}
