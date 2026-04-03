import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Key for [DateTime] set in [RequestOptions.extra] to measure round-trip time.
const String _requestStartTimeKey = 'vaxiil_request_start_time';

class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_requestStartTimeKey] = DateTime.now();
    if (_shouldLog()) {
      _logRequest(options);
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (_shouldLog()) {
      _logResponse(response);
    }
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (_shouldLog()) {
      _logError(err);
    }
    super.onError(err, handler);
  }

  bool _shouldLog() {
    return true;
  }

  void _logRequest(RequestOptions options) {
    final buffer = StringBuffer();
    buffer.writeln('=== API Request ===');
    buffer.writeln('URL: ${options.uri}');
    buffer.writeln('Method: ${options.method}');
    buffer.writeln('Headers: ${_formatHeaders(options.headers)}');

    if (options.data != null) {
      buffer.writeln('Request Data:');
      buffer.writeln(_formatData(options.data));
    }

    if (options.queryParameters.isNotEmpty) {
      buffer.writeln('Query Parameters: ${options.queryParameters}');
    }

    buffer.writeln('Timestamp: ${DateTime.now()}');
    buffer.writeln('==================');

    debugPrint(buffer.toString());
  }

  void _logResponse(Response<dynamic> response) {
    final buffer = StringBuffer();
    buffer.writeln('=== API Response ===');
    buffer.writeln('URL: ${response.requestOptions.uri}');
    buffer.writeln('Method: ${response.requestOptions.method}');
    buffer.writeln('Status Code: ${response.statusCode}');
    buffer.writeln('Status Message: ${response.statusMessage}');
    buffer.writeln('Headers: ${_formatHeaders(response.headers)}');

    buffer.writeln('Response Data:');
    buffer.writeln(_formatData(response.data));

    final start = response.requestOptions.extra[_requestStartTimeKey] as DateTime?;
    if (start != null) {
      buffer.writeln('Duration: ${DateTime.now().difference(start)}');
    }

    buffer.writeln('Timestamp: ${DateTime.now()}');
    buffer.writeln('==================');

    debugPrint(buffer.toString());
  }

  void _logError(DioException err) {
    final buffer = StringBuffer();
    buffer.writeln('=== API Error ===');
    buffer.writeln('Type: ${err.type}');
    buffer.writeln('Message: ${err.message}');
    buffer.writeln('URL: ${err.requestOptions.uri}');
    buffer.writeln('Method: ${err.requestOptions.method}');
    buffer.writeln('Headers: ${_formatHeaders(err.requestOptions.headers)}');

    if (err.requestOptions.data != null) {
      buffer.writeln('Request Data:');
      buffer.writeln(_formatData(err.requestOptions.data));
    }

    if (err.requestOptions.queryParameters.isNotEmpty) {
      buffer.writeln('Query Parameters: ${err.requestOptions.queryParameters}');
    }

    if (err.response != null) {
      buffer.writeln('Response Status: ${err.response?.statusCode}');
      buffer.writeln('Response Message: ${err.response?.statusMessage}');
      buffer.writeln(
        'Response Headers: ${_formatHeaders(err.response?.headers)}',
      );
      buffer.writeln('Response Data:');
      buffer.writeln(_formatData(err.response?.data));
    }

    buffer.writeln('Timestamp: ${DateTime.now()}');
    buffer.writeln('==================');

    debugPrint(buffer.toString());
  }

  String _formatHeaders(Object? raw) {
    Map<String, dynamic> map;
    if (raw == null) {
      map = {};
    } else if (raw is Headers) {
      map = {};
      for (final entry in raw.map.entries) {
        final v = entry.value;
        map[entry.key] =
            v.length == 1 ? v.first : v.join(', ');
      }
    } else if (raw is Map<String, dynamic>) {
      map = Map<String, dynamic>.from(raw);
    } else if (raw is Map) {
      map = raw.map((k, dynamic v) => MapEntry(k.toString(), v));
    } else {
      return raw.toString();
    }

    map.remove('authorization');
    map.remove('cookie');
    map.remove('x-api-key');

    return map.toString();
  }

  String _formatData(dynamic data) {
    if (data == null) return 'null';

    var dataString = data.toString();
    if (dataString.length > 1000) {
      dataString = '${dataString.substring(0, 1000)}... (truncated)';
    }

    return dataString;
  }
}
