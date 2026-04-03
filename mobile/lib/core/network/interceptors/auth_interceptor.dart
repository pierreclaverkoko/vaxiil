import 'package:dio/dio.dart';
import 'package:vaxiil_mobile/core/constants/app_constants.dart';
import 'package:vaxiil_mobile/core/storage/secure_storage_service.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._secureStorage);
  final SecureStorageService _secureStorage;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!_isAuthEndpoint(options.path)) {
      _addAuthToken(options);
    }
    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      _handleUnauthorizedError(err, handler);
      return;
    }
    super.onError(err, handler);
  }

  Future<void> _addAuthToken(RequestOptions options) async {
    try {
      final token = await _secureStorage.readString(AppConstants.accessTokenKey);
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {}
  }

  /// Paths that must not receive an Authorization header.
  bool _isAuthEndpoint(String path) {
    final p = path.toLowerCase();
    return p.contains('auth/login') ||
        p.contains('auth/register') ||
        p.contains('auth/token/refresh') ||
        p.contains('auth/google');
  }

  Future<void> _handleUnauthorizedError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    try {
      final refreshToken = await _secureStorage.readString(AppConstants.refreshTokenKey);
      if (refreshToken == null || refreshToken.isEmpty) {
        super.onError(err, handler);
        return;
      }

      final refreshDio = Dio(
        BaseOptions(
          baseUrl: AppConstants.apiBaseUrl.endsWith('/')
              ? AppConstants.apiBaseUrl
              : '${AppConstants.apiBaseUrl}/',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      final response = await refreshDio.post<Map<String, dynamic>>(
        AppConstants.authTokenRefreshPath,
        data: {'refresh': refreshToken},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data!;
        final accessRaw = data['access'];
        final refreshRaw = data['refresh'];
        if (accessRaw == null) {
          super.onError(err, handler);
          return;
        }
        final newAccess = accessRaw is String ? accessRaw : accessRaw.toString();
        final newRefresh = refreshRaw == null
            ? refreshToken
            : (refreshRaw is String ? refreshRaw : refreshRaw.toString());

        await _secureStorage.saveTokens(
          accessToken: newAccess,
          refreshToken: newRefresh,
        );

        final originalRequest = err.requestOptions;
        originalRequest.headers['Authorization'] = 'Bearer $newAccess';

        try {
          final retryResponse =
              await Dio().fetch<Response<dynamic>>(originalRequest);
          handler.resolve(retryResponse);
          return;
        } catch (_) {
          super.onError(err, handler);
          return;
        }
      }
      super.onError(err, handler);
    } catch (_) {
      await _secureStorage.delete(AppConstants.accessTokenKey);
      await _secureStorage.delete(AppConstants.refreshTokenKey);
      super.onError(err, handler);
    }
  }
}
