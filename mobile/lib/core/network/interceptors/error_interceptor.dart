import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';

class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logError(err);
    final failure = _convertToFailure(err);
    final updated = err.copyWith(error: failure);
    super.onError(updated, handler);
  }

  void _logError(DioException err) {
    final buffer = StringBuffer();
    buffer.writeln('=== API Error ===');
    buffer.writeln('Type: ${err.type}');
    buffer.writeln('Message: ${err.message}');
    buffer.writeln('URL: ${err.requestOptions.uri}');
    buffer.writeln('Method: ${err.requestOptions.method}');

    if (err.response != null) {
      buffer.writeln('Status Code: ${err.response?.statusCode}');
      buffer.writeln('Status Message: ${err.response?.statusMessage}');
      buffer.writeln('Response Data: ${err.response?.data}');
    }

    if (err.requestOptions.data != null) {
      buffer.writeln('Request Data: ${err.requestOptions.data}');
    }

    if (err.requestOptions.queryParameters.isNotEmpty) {
      buffer.writeln('Query Parameters: ${err.requestOptions.queryParameters}');
    }

    buffer.writeln('Timestamp: ${DateTime.now()}');
    buffer.writeln('==================');

    debugPrint(buffer.toString());
  }

  Failure _convertToFailure(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkFailure.timeout();

      case DioExceptionType.badResponse:
        return _handleHttpError(
          err.response?.statusCode ?? 0,
          err.response?.data,
        );

      case DioExceptionType.cancel:
        return const NetworkFailure(
          message: 'Request cancelled',
          code: 'REQUEST_CANCELLED',
        );

      case DioExceptionType.connectionError:
        return NetworkFailure.noConnection();

      case DioExceptionType.unknown:
        if (err.error?.toString().contains('SocketException') == true) {
          return NetworkFailure.noConnection();
        }
        return NetworkFailure.unknown(message: err.message);

      default:
        return NetworkFailure.unknown(message: err.message);
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
        return _handleValidationError(responseData);
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

  Failure _handleValidationError(dynamic responseData) {
    final errors = _errorsMapFromResponse(responseData);

    if (errors != null && errors.isNotEmpty) {
      final firstField = errors.keys.first;
      final firstError = errors[firstField];
      if (firstError is List && firstError.isNotEmpty) {
        return ValidationFailure(
          message: firstError.first.toString(),
          code: 'VALIDATION_ERROR',
          details: {'field': firstField},
        );
      }
    }

    return ValidationFailure.invalidFormat('field');
  }
}
