import 'package:dio/dio.dart';
import 'package:vaxiil_mobile/core/constants/app_constants.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/core/network/interceptors/accept_language_interceptor.dart';
import 'package:vaxiil_mobile/core/network/interceptors/auth_interceptor.dart';
import 'package:vaxiil_mobile/core/network/interceptors/error_interceptor.dart';
import 'package:vaxiil_mobile/core/network/interceptors/logging_interceptor.dart';
import 'package:vaxiil_mobile/core/storage/secure_storage_service.dart';

class DioClient {

  DioClient({SecureStorageService? secureStorage}) {
    _secureStorage = secureStorage ?? SecureStorageService();
    _dio = Dio(_createBaseOptions());
    _setupInterceptors();
  }
  late final Dio _dio;
  late final SecureStorageService _secureStorage;

  Dio get dio => _dio;

  BaseOptions _createBaseOptions() {
    return BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: AppConstants.connectTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      sendTimeout: AppConstants.requestTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );
  }

  void _setupInterceptors() {
    final auth = AuthInterceptor(_secureStorage);
    auth.attachClient(_dio);
    _dio.interceptors.addAll([
      AcceptLanguageInterceptor(),
      auth,
      ErrorInterceptor(),
      LoggingInterceptor(),
    ]);
  }

  // GET request
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // POST request
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // PUT request
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // PATCH request
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // DELETE request
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // FormData request (for file uploads)
  Future<Response<T>> upload<T>(
    String path, {
    required FormData formData,
    Map<String, dynamic>? queryParameters,
    Options? options,
    ProgressCallback? onSendProgress,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: formData,
        queryParameters: queryParameters,
        options: options,
        onSendProgress: onSendProgress,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Download request
  Future<Response> download(
    String urlPath,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.download(
        urlPath,
        savePath,
        onReceiveProgress: onReceiveProgress,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  static String _messageFromResponse(dynamic responseData) {
    if (responseData is! Map) return 'Unknown error';
    final raw = responseData['message'];
    if (raw == null) return 'Unknown error';
    if (raw is String) return raw;
    return raw.toString();
  }

  static Map<String, dynamic>? _errorsMapFromResponse(dynamic responseData) {
    if (responseData is! Map) return null;
    final raw = responseData['errors'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  // Handle Dio exceptions and convert to custom failures
  Failure _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkFailure.timeout();
      
      case DioExceptionType.badResponse:
        return _handleHttpError(error.response?.statusCode ?? 0, error.response?.data);
      
      case DioExceptionType.cancel:
        return const NetworkFailure(
          message: 'Request cancelled',
          code: 'REQUEST_CANCELLED',
        );
      
      case DioExceptionType.connectionError:
        return NetworkFailure.noConnection();

      case DioExceptionType.unknown:
        if (error.error?.toString().contains('SocketException') == true) {
          return NetworkFailure.noConnection();
        }
        return NetworkFailure.unknown(message: error.message);
      
      default:
        return NetworkFailure.unknown(message: error.message);
    }
  }

  Failure _handleHttpError(int statusCode, dynamic responseData) {
    final message = _messageFromResponse(responseData);
    final errors = _errorsMapFromResponse(responseData);
    
    switch (statusCode) {
      case 400:
        return NetworkFailure.badRequest(message: message, details: errors);
      case 401:
        return NetworkFailure.unauthorized(message: message);
      case 403:
        return NetworkFailure.forbidden(message: message);
      case 404:
        return NetworkFailure.notFound(message: message);
      case 422:
        return ValidationFailure.invalidFormat('field');
      case 429:
        return const NetworkFailure(
          message: 'Too many requests',
          code: 'TOO_MANY_REQUESTS',
        );
      case 500:
      case 502:
      case 503:
      case 504:
        return NetworkFailure.serverError(message: message);
      default:
        return NetworkFailure.unknown(message: message);
    }
  }

  // Update base URL (useful for different environments)
  void updateBaseUrl(String newBaseUrl) {
    _dio.options.baseUrl = newBaseUrl;
  }

  // Add custom header
  void addHeader(String key, String value) {
    _dio.options.headers[key] = value;
  }

  // Remove custom header
  void removeHeader(String key) {
    _dio.options.headers.remove(key);
  }

  // Clear all custom headers
  void clearHeaders() {
    _dio.options.headers.clear();
    _dio.options.headers.addAll({
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    });
  }
}
