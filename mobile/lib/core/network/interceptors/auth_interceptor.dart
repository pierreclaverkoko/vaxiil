import 'package:dio/dio.dart';
import 'package:vaxiil_mobile/core/constants/app_constants.dart';
import 'package:vaxiil_mobile/core/storage/secure_storage_service.dart';

class AuthInterceptor extends Interceptor {

  AuthInterceptor(this._secureStorage);
  final SecureStorageService _secureStorage;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Add authentication token to all requests except auth endpoints
    if (!_isAuthEndpoint(options.path)) {
      _addAuthToken(options);
    }
    
    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Handle 401 errors - token refresh logic
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
    } catch (e) {
      // If we can't read the token, continue without it
      // The request will fail and be handled by the error interceptor
    }
  }

  bool _isAuthEndpoint(String path) {
    return path.contains(AppConstants.authEndpoint);
  }

  Future<void> _handleUnauthorizedError(DioException err, ErrorInterceptorHandler handler) async {
    try {
      // Try to refresh the token
      final refreshToken = await _secureStorage.readString(AppConstants.refreshTokenKey);
      
      if (refreshToken == null || refreshToken.isEmpty) {
        // No refresh token, let the error propagate
        super.onError(err, handler);
        return;
      }

      // Create a new Dio instance to avoid infinite loops
      final refreshDio = Dio();
      refreshDio.options.baseUrl = AppConstants.apiBaseUrl;
      
      final response = await refreshDio.post(
        '${AppConstants.authEndpoint}/refresh',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        final newAccessToken = response.data['access_token'];
        final newRefreshToken = response.data['refresh_token'];
        
        // Save new tokens
        await _secureStorage.writeString(AppConstants.accessTokenKey, newAccessToken);
        if (newRefreshToken != null) {
          await _secureStorage.writeString(AppConstants.refreshTokenKey, newRefreshToken);
        }

        // Retry the original request with new token
        final originalRequest = err.requestOptions;
        originalRequest.headers['Authorization'] = 'Bearer $newAccessToken';
        
        try {
          final retryResponse = await refreshDio.fetch(originalRequest);
          handler.resolve(retryResponse);
          return;
        } catch (retryError) {
          // Retry failed, propagate the error
          super.onError(err, handler);
          return;
        }
      } else {
        // Refresh failed, propagate the error
        super.onError(err, handler);
        return;
      }
    } catch (e) {
      // Token refresh failed, clear tokens and propagate error
      await _secureStorage.delete(AppConstants.accessTokenKey);
      await _secureStorage.delete(AppConstants.refreshTokenKey);
      
      super.onError(err, handler);
    }
  }
}
