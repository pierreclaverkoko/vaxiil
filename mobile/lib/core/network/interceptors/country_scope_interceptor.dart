import 'package:dio/dio.dart';
import 'package:vaxiil_mobile/core/country/country_scope_service.dart';

/// Attach X-Timezone / X-Country; hydrate from X-Resolved-Country when empty.
class CountryScopeInterceptor extends Interceptor {
  CountryScopeInterceptor(this._scope);

  final CountryScopeService _scope;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final tz = _scope.timezone;
    if (tz.isNotEmpty) {
      options.headers['X-Timezone'] = tz;
    }
    final iso = _scope.isoCode2;
    if (iso.isNotEmpty) {
      options.headers['X-Country'] = iso;
    }
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final resolved = response.headers.value('x-resolved-country') ??
        response.headers.value('X-Resolved-Country');
    _scope.hydrateFromResolvedIso2(resolved);
    handler.next(response);
  }
}
