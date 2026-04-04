import 'package:dio/dio.dart';
import 'package:vaxiil_mobile/core/constants/app_constants.dart';
import 'package:vaxiil_mobile/core/storage/secure_storage_service.dart';

const String _kAuthRetryExtraKey = '__auth_retry__';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._secureStorage);
  final SecureStorageService _secureStorage;

  Dio? _client;

  /// Must be called with the same [Dio] that uses this interceptor so retries
  /// reuse transformers, timeouts, and base options (e.g. multipart).
  void attachClient(Dio client) {
    _client = client;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_isAuthEndpoint(options.path)) {
      handler.next(options);
      return;
    }
    _addAuthToken(options).then((_) {
      handler.next(options);
    }).catchError((Object error, StackTrace stackTrace) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          stackTrace: stackTrace,
        ),
      );
    });
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.requestOptions.extra[_kAuthRetryExtraKey] == true) {
      super.onError(err, handler);
      return;
    }
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
        originalRequest.extra[_kAuthRetryExtraKey] = true;

        final client = _client;
        if (client == null) {
          super.onError(err, handler);
          return;
        }

        final method = originalRequest.method.toUpperCase();
        if (method != 'GET') {
          // Only safe reads are replayed after refresh (no POST/PUT/PATCH/DELETE).
          super.onError(err, handler);
          return;
        }

        try {
          final retryResponse =
              await client.fetch<Response<dynamic>>(originalRequest);
          handler.resolve(retryResponse);
          return;
        } catch (_) {
          super.onError(err, handler);
          return;
        }
      }

      final refreshCode = response.statusCode;
      if (refreshCode == 400 || refreshCode == 403) {
        await _clearAuthTokens();
      }
      super.onError(err, handler);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.badResponse) {
        final code = e.response?.statusCode;
        if (code == 400 || code == 403) {
          await _clearAuthTokens();
        }
      }
      super.onError(err, handler);
    }
  }

  Future<void> _clearAuthTokens() async {
    await _secureStorage.delete(AppConstants.accessTokenKey);
    await _secureStorage.delete(AppConstants.refreshTokenKey);
  }
}
