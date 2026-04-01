import 'package:dio/dio.dart';

class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_shouldLog()) {
      _logRequest(options);
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
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
    // In debug mode, log everything
    // In release mode, you might want to log only errors
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

  void _logResponse(Response response) {
    final buffer = StringBuffer();
    buffer.writeln('=== API Response ===');
    buffer.writeln('URL: ${response.requestOptions.uri}');
    buffer.writeln('Method: ${response.requestOptions.method}');
    buffer.writeln('Status Code: ${response.statusCode}');
    buffer.writeln('Status Message: ${response.statusMessage}');
    buffer.writeln('Headers: ${_formatHeaders(response.headers)}');
    
    buffer.writeln('Response Data:');
    buffer.writeln(_formatData(response.data));
    
    buffer.writeln('Duration: ${DateTime.now().difference(response.requestOptions.headers['request_time'] as DateTime? ?? DateTime.now())}');
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
      buffer.writeln('Response Headers: ${_formatHeaders(err.response?.headers ?? {}})');
      buffer.writeln('Response Data:');
      buffer.writeln(_formatData(err.response?.data));
    }
    
    buffer.writeln('Timestamp: ${DateTime.now()}');
    buffer.writeln('==================');
    
    debugPrint(buffer.toString());
  }

  String _formatHeaders(Map<String, dynamic> headers) {
    // Filter sensitive headers
    final filteredHeaders = Map<String, dynamic>.from(headers);
    filteredHeaders.remove('authorization');
    filteredHeaders.remove('cookie');
    filteredHeaders.remove('x-api-key');
    
    return filteredHeaders.toString();
  }

  String _formatData(dynamic data) {
    if (data == null) return 'null';
    
    // Limit the size of logged data to avoid huge logs
    var dataString = data.toString();
    if (dataString.length > 1000) {
      dataString = '${dataString.substring(0, 1000)}... (truncated)';
    }
    
    return dataString;
  }
}
