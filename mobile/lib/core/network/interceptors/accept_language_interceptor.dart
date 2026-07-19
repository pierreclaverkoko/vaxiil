import 'package:dio/dio.dart';
import 'package:vaxiil_mobile/core/locale/locale_manager.dart';

/// Sends the active UI locale so Django LocaleMiddleware can translate
/// choice titles and API error messages.
class AcceptLanguageInterceptor extends Interceptor {
  AcceptLanguageInterceptor([LocaleManager? localeManager])
      : _localeManager = localeManager ?? LocaleManager();

  final LocaleManager _localeManager;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['Accept-Language'] = _localeManager.languageCode;
    handler.next(options);
  }
}
