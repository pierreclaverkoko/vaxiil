import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error,
  fatal,
}

class Logger {
  static const String _tag = 'Vaxiil';
  static bool _enableLogging = kDebugMode;
  
  // Enable/disable logging
  static void enableLogging(bool enable) {
    _enableLogging = enable;
  }
  
  // Debug logs
  static void debug(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.debug, message, tag: tag, error: error, stackTrace: stackTrace);
  }
  
  // Info logs
  static void info(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.info, message, tag: tag, error: error, stackTrace: stackTrace);
  }
  
  // Warning logs
  static void warning(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.warning, message, tag: tag, error: error, stackTrace: stackTrace);
  }
  
  // Error logs
  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message, tag: tag, error: error, stackTrace: stackTrace);
  }
  
  // Fatal logs
  static void fatal(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.fatal, message, tag: tag, error: error, stackTrace: stackTrace);
  }
  
  // Internal logging method
  static void _log(
    LogLevel level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!_enableLogging) return;
    
    final logTag = tag ?? _tag;
    final timestamp = DateTime.now().toIso8601String();
    final levelString = level.name.toUpperCase();
    
    final logMessage = '[$timestamp] $levelString [$logTag]: $message';
    
    switch (level) {
      case LogLevel.debug:
        developer.log(logMessage, level: level.value, error: error, stackTrace: stackTrace);
      case LogLevel.info:
        developer.log(logMessage, level: level.value, error: error, stackTrace: stackTrace);
      case LogLevel.warning:
        developer.log(logMessage, level: level.value, error: error, stackTrace: stackTrace);
      case LogLevel.error:
        developer.log(logMessage, level: level.value, error: error, stackTrace: stackTrace);
      case LogLevel.fatal:
        developer.log(logMessage, level: level.value, error: error, stackTrace: stackTrace);
    }
  }
  
  // Log API requests
  static void logApiRequest({
    required String method,
    required String url,
    Map<String, dynamic>? headers,
    dynamic body,
  }) {
    debug(
      'API Request: $method $url',
      tag: 'API',
      error: {
        'headers': headers,
        'body': body,
      },
    );
  }
  
  // Log API responses
  static void logApiResponse({
    required String method,
    required String url,
    required int statusCode,
    dynamic response,
    Duration? duration,
  }) {
    debug(
      'API Response: $method $url - $statusCode (${duration?.inMilliseconds ?? 0}ms)',
      tag: 'API',
      error: {
        'status_code': statusCode,
        'response': response,
        'duration_ms': duration?.inMilliseconds,
      },
    );
  }
  
  // Log user actions
  static void logUserAction(String action, {Map<String, dynamic>? data}) {
    info(
      'User Action: $action',
      tag: 'USER',
      error: data,
    );
  }
  
  // Log navigation events
  static void logNavigation(String route, {String? from}) {
    info(
      'Navigation: $route',
      tag: 'NAVIGATION',
      error: from != null ? {'from': from} : null,
    );
  }
  
  // Log performance metrics
  static void logPerformance(String operation, Duration duration, {Map<String, dynamic>? data}) {
    info(
      'Performance: $operation took ${duration.inMilliseconds}ms',
      tag: 'PERFORMANCE',
      error: {
        'operation': operation,
        'duration_ms': duration.inMilliseconds,
        ...?data,
      },
    );
  }
  
  // Log errors with context
  static void logErrorWithContext(
    String message,
    Object error,
    StackTrace stackTrace, {
    Map<String, dynamic>? context,
  }) {
    _log(
      LogLevel.error,
      message,
      tag: 'ERROR',
      error: {
        'error': error.toString(),
        'stack_trace': stackTrace.toString(),
        ...?context,
      },
      stackTrace: stackTrace,
    );
  }
  
  // Log authentication events
  static void logAuthEvent(String event, {String? userId, Map<String, dynamic>? data}) {
    info(
      'Auth Event: $event',
      tag: 'AUTH',
      error: {
        'user_id': userId,
        ...?data,
      },
    );
  }
  
  // Log business events
  static void logBusinessEvent(String event, {String? businessId, Map<String, dynamic>? data}) {
    info(
      'Business Event: $event',
      tag: 'BUSINESS',
      error: {
        'business_id': businessId,
        ...?data,
      },
    );
  }
  
  // Log booking events
  static void logBookingEvent(String event, {String? bookingId, Map<String, dynamic>? data}) {
    info(
      'Booking Event: $event',
      tag: 'BOOKING',
      error: {
        'booking_id': bookingId,
        ...?data,
      },
    );
  }
  
  // Log payment events
  static void logPaymentEvent(String event, {String? paymentId, Map<String, dynamic>? data}) {
    info(
      'Payment Event: $event',
      tag: 'PAYMENT',
      error: {
        'payment_id': paymentId,
        ...?data,
      },
    );
  }
}

// Extension on LogLevel to get numeric value
extension LogLevelExtension on LogLevel {
  int get value {
    switch (this) {
      case LogLevel.debug:
        return 0;
      case LogLevel.info:
        return 1;
      case LogLevel.warning:
        return 2;
      case LogLevel.error:
        return 3;
      case LogLevel.fatal:
        return 4;
    }
  }
}

// Logger mixin for classes that need logging
mixin LoggerMixin {
  String get loggerTag => runtimeType.toString();
  
  void logDebug(String message, {Object? error, StackTrace? stackTrace}) {
    Logger.debug(message, tag: loggerTag, error: error, stackTrace: stackTrace);
  }
  
  void logInfo(String message, {Object? error, StackTrace? stackTrace}) {
    Logger.info(message, tag: loggerTag, error: error, stackTrace: stackTrace);
  }
  
  void logWarning(String message, {Object? error, StackTrace? stackTrace}) {
    Logger.warning(message, tag: loggerTag, error: error, stackTrace: stackTrace);
  }
  
  void logError(String message, {Object? error, StackTrace? stackTrace}) {
    Logger.error(message, tag: loggerTag, error: error, stackTrace: stackTrace);
  }
  
  void logFatal(String message, {Object? error, StackTrace? stackTrace}) {
    Logger.fatal(message, tag: loggerTag, error: error, stackTrace: stackTrace);
  }
}
