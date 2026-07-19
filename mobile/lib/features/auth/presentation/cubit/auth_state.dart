import 'package:equatable/equatable.dart';
import 'package:vaxiil_mobile/features/auth/domain/entities/auth_user.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState extends Equatable {
  const AuthState({
    required this.status,
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.otpChallengeId,
    this.otpEmailHint,
  });

  final AuthStatus status;
  final AuthUser? user;
  final bool isLoading;
  final String? errorMessage;

  /// When set, login requires email OTP before a session is issued.
  final String? otpChallengeId;
  final String? otpEmailHint;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  bool get requiresOtp =>
      otpChallengeId != null && otpChallengeId!.isNotEmpty;

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? otpChallengeId,
    String? otpEmailHint,
    bool clearOtp = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      otpChallengeId:
          clearOtp ? null : (otpChallengeId ?? this.otpChallengeId),
      otpEmailHint: clearOtp ? null : (otpEmailHint ?? this.otpEmailHint),
    );
  }

  @override
  List<Object?> get props => [
        status,
        user,
        isLoading,
        errorMessage,
        otpChallengeId,
        otpEmailHint,
      ];
}
