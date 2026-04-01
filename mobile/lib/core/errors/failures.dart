import 'package:equatable/equatable.dart';

// Base failure class
abstract class Failure extends Equatable {
  const Failure({
    required this.message,
    this.code,
    this.details,
  });

  final String message;
  final String? code;
  final Map<String, dynamic>? details;

  @override
  List<Object?> get props => [message, code, details];

  @override
  String toString() => 'Failure(message: $message, code: $code)';
}

// Network failures
class NetworkFailure extends Failure {
  const NetworkFailure({
    required super.message,
    super.code,
    super.details,
  });

  factory NetworkFailure.noConnection() {
    return const NetworkFailure(
      message: 'No internet connection',
      code: 'NO_CONNECTION',
    );
  }

  factory NetworkFailure.timeout() {
    return const NetworkFailure(
      message: 'Request timeout',
      code: 'TIMEOUT',
    );
  }

  factory NetworkFailure.serverError({String? message}) {
    return NetworkFailure(
      message: message ?? 'Server error occurred',
      code: 'SERVER_ERROR',
    );
  }

  factory NetworkFailure.unauthorized({String? message}) {
    return NetworkFailure(
      message: message ?? 'Unauthorized access',
      code: 'UNAUTHORIZED',
    );
  }

  factory NetworkFailure.forbidden({String? message}) {
    return NetworkFailure(
      message: message ?? 'Access forbidden',
      code: 'FORBIDDEN',
    );
  }

  factory NetworkFailure.notFound({String? message}) {
    return NetworkFailure(
      message: message ?? 'Resource not found',
      code: 'NOT_FOUND',
    );
  }

  factory NetworkFailure.badRequest({String? message, Map<String, dynamic>? details}) {
    return NetworkFailure(
      message: message ?? 'Bad request',
      code: 'BAD_REQUEST',
      details: details,
    );
  }

  factory NetworkFailure.unknown({String? message}) {
    return NetworkFailure(
      message: message ?? 'Unknown network error',
      code: 'UNKNOWN',
    );
  }
}

// Validation failures
class ValidationFailure extends Failure {
  const ValidationFailure({
    required super.message,
    super.code,
    super.details,
  });

  factory ValidationFailure.requiredField(String fieldName) {
    return ValidationFailure(
      message: '$fieldName is required',
      code: 'REQUIRED_FIELD',
      details: {'field': fieldName},
    );
  }

  factory ValidationFailure.invalidEmail() {
    return const ValidationFailure(
      message: 'Invalid email address',
      code: 'INVALID_EMAIL',
    );
  }

  factory ValidationFailure.invalidPassword() {
    return const ValidationFailure(
      message: 'Password must be at least 8 characters',
      code: 'INVALID_PASSWORD',
    );
  }

  factory ValidationFailure.passwordMismatch() {
    return const ValidationFailure(
      message: 'Passwords do not match',
      code: 'PASSWORD_MISMATCH',
    );
  }

  factory ValidationFailure.invalidPhone() {
    return const ValidationFailure(
      message: 'Invalid phone number',
      code: 'INVALID_PHONE',
    );
  }

  factory ValidationFailure.invalidFormat(String fieldName) {
    return ValidationFailure(
      message: 'Invalid $fieldName format',
      code: 'INVALID_FORMAT',
      details: {'field': fieldName},
    );
  }
}

// Authentication failures
class AuthenticationFailure extends Failure {
  const AuthenticationFailure({
    required super.message,
    super.code,
    super.details,
  });

  factory AuthenticationFailure.invalidCredentials() {
    return const AuthenticationFailure(
      message: 'Invalid email or password',
      code: 'INVALID_CREDENTIALS',
    );
  }

  factory AuthenticationFailure.userNotFound() {
    return const AuthenticationFailure(
      message: 'User not found',
      code: 'USER_NOT_FOUND',
    );
  }

  factory AuthenticationFailure.emailAlreadyExists() {
    return const AuthenticationFailure(
      message: 'Email already exists',
      code: 'EMAIL_ALREADY_EXISTS',
    );
  }

  factory AuthenticationFailure.tokenExpired() {
    return const AuthenticationFailure(
      message: 'Authentication token expired',
      code: 'TOKEN_EXPIRED',
    );
  }

  factory AuthenticationFailure.tokenInvalid() {
    return const AuthenticationFailure(
      message: 'Invalid authentication token',
      code: 'TOKEN_INVALID',
    );
  }

  factory AuthenticationFailure.accountDisabled() {
    return const AuthenticationFailure(
      message: 'Account has been disabled',
      code: 'ACCOUNT_DISABLED',
    );
  }

  factory AuthenticationFailure.notVerified() {
    return const AuthenticationFailure(
      message: 'Account not verified',
      code: 'NOT_VERIFIED',
    );
  }
}

// Business logic failures
class BusinessFailure extends Failure {
  const BusinessFailure({
    required super.message,
    super.code,
    super.details,
  });

  factory BusinessFailure.bookingNotAvailable() {
    return const BusinessFailure(
      message: 'Booking slot not available',
      code: 'BOOKING_NOT_AVAILABLE',
    );
  }

  factory BusinessFailure.bookingAlreadyExists() {
    return const BusinessFailure(
      message: 'Booking already exists',
      code: 'BOOKING_ALREADY_EXISTS',
    );
  }

  factory BusinessFailure.bookingNotFound() {
    return const BusinessFailure(
      message: 'Booking not found',
      code: 'BOOKING_NOT_FOUND',
    );
  }

  factory BusinessFailure.bookingCannotBeCancelled() {
    return const BusinessFailure(
      message: 'Booking cannot be cancelled',
      code: 'BOOKING_CANNOT_BE_CANCELLED',
    );
  }

  factory BusinessFailure.insufficientBalance() {
    return const BusinessFailure(
      message: 'Insufficient balance',
      code: 'INSUFFICIENT_BALANCE',
    );
  }

  factory BusinessFailure.paymentFailed() {
    return const BusinessFailure(
      message: 'Payment failed',
      code: 'PAYMENT_FAILED',
    );
  }

  factory BusinessFailure.serviceNotAvailable() {
    return const BusinessFailure(
      message: 'Service not available',
      code: 'SERVICE_NOT_AVAILABLE',
    );
  }

  factory BusinessFailure.businessNotFound() {
    return const BusinessFailure(
      message: 'Business not found',
      code: 'BUSINESS_NOT_FOUND',
    );
  }
}

// Storage failures
class StorageFailure extends Failure {
  const StorageFailure({
    required super.message,
    super.code,
    super.details,
  });

  factory StorageFailure.readError() {
    return const StorageFailure(
      message: 'Failed to read from storage',
      code: 'READ_ERROR',
    );
  }

  factory StorageFailure.writeError() {
    return const StorageFailure(
      message: 'Failed to write to storage',
      code: 'WRITE_ERROR',
    );
  }

  factory StorageFailure.deleteError() {
    return const StorageFailure(
      message: 'Failed to delete from storage',
      code: 'DELETE_ERROR',
    );
  }

  factory StorageFailure.dataCorrupted() {
    return const StorageFailure(
      message: 'Data corrupted',
      code: 'DATA_CORRUPTED',
    );
  }
}

// Permission failures
class PermissionFailure extends Failure {
  const PermissionFailure({
    required super.message,
    super.code,
    super.details,
  });

  factory PermissionFailure.denied(String permission) {
    return PermissionFailure(
      message: '$permission permission denied',
      code: 'PERMISSION_DENIED',
      details: {'permission': permission},
    );
  }

  factory PermissionFailure.permanentlyDenied(String permission) {
    return PermissionFailure(
      message: '$permission permission permanently denied',
      code: 'PERMISSION_PERMANENTLY_DENIED',
      details: {'permission': permission},
    );
  }

  factory PermissionFailure.restricted(String permission) {
    return PermissionFailure(
      message: '$permission permission restricted',
      code: 'PERMISSION_RESTRICTED',
      details: {'permission': permission},
    );
  }
}

// Cache failures
class CacheFailure extends Failure {
  const CacheFailure({
    required super.message,
    super.code,
    super.details,
  });

  factory CacheFailure.notFound() {
    return const CacheFailure(
      message: 'Cache not found',
      code: 'CACHE_NOT_FOUND',
    );
  }

  factory CacheFailure.expired() {
    return const CacheFailure(
      message: 'Cache expired',
      code: 'CACHE_EXPIRED',
    );
  }

  factory CacheFailure.corrupted() {
    return const CacheFailure(
      message: 'Cache corrupted',
      code: 'CACHE_CORRUPTED',
    );
  }
}
