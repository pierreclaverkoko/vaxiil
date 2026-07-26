import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/features/auth/data/auth_metadata_models.dart';
import 'package:vaxiil_mobile/features/auth/data/auth_repository.dart';
import 'package:vaxiil_mobile/features/auth/data/login_result.dart';
import 'package:vaxiil_mobile/features/auth/domain/entities/auth_user.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repository)
      : super(const AuthState(status: AuthStatus.unknown));

  final AuthRepository _repository;

  Future<void> checkSession() async {
    emit(const AuthState(status: AuthStatus.unknown, isLoading: true));
    try {
      final user = await _repository.restoreSession();
      if (user != null) {
        emit(AuthState(status: AuthStatus.authenticated, user: user));
      } else {
        emit(const AuthState(status: AuthStatus.unauthenticated));
      }
    } catch (_) {
      emit(const AuthState(status: AuthStatus.unauthenticated));
    }
  }

  Future<void> login({
    required String email,
    required String password,
    required String turnstileToken,
  }) async {
    emit(
      const AuthState(
        status: AuthStatus.unauthenticated,
        isLoading: true,
      ),
    );
    try {
      final result = await _repository.login(
        email: email,
        password: password,
        turnstileToken: turnstileToken,
      );
      switch (result) {
        case LoginSessionResult(:final user):
          emit(AuthState(status: AuthStatus.authenticated, user: user));
        case LoginOtpChallengeResult(:final challengeId, :final emailHint):
          emit(
            AuthState(
              status: AuthStatus.unauthenticated,
              otpChallengeId: challengeId,
              otpEmailHint: emailHint,
            ),
          );
      }
    } on Failure catch (f) {
      emit(
        AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: f.message,
        ),
      );
    } catch (e) {
      emit(
        AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> verifyLoginOtp({
    required String code,
    required String turnstileToken,
  }) async {
    final challengeId = state.otpChallengeId;
    if (challengeId == null || challengeId.isEmpty) {
      emit(
        state.copyWith(
          errorMessage: 'No verification challenge in progress',
          isLoading: false,
        ),
      );
      return;
    }
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final user = await _repository.verifyLoginOtp(
        challengeId: challengeId,
        code: code,
        turnstileToken: turnstileToken,
      );
      emit(AuthState(status: AuthStatus.authenticated, user: user));
    } on Failure catch (f) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: f.message,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void clearOtpChallenge() {
    emit(state.copyWith(clearOtp: true, clearError: true, isLoading: false));
  }

  Future<void> register({
    required String email,
    required String username,
    required String password,
    required String passwordConfirm,
    required String acceptedTermsVersion,
    required String acceptedPrivacyVersion,
    required String turnstileToken,
    String? firstName,
    String? lastName,
  }) async {
    emit(
      const AuthState(
        status: AuthStatus.unauthenticated,
        isLoading: true,
      ),
    );
    try {
      final user = await _repository.register(
        email: email,
        username: username,
        password: password,
        passwordConfirm: passwordConfirm,
        acceptedTermsVersion: acceptedTermsVersion,
        acceptedPrivacyVersion: acceptedPrivacyVersion,
        turnstileToken: turnstileToken,
        firstName: firstName,
        lastName: lastName,
      );
      emit(AuthState(status: AuthStatus.authenticated, user: user));
    } on Failure catch (f) {
      emit(
        AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: f.message,
        ),
      );
    } catch (e) {
      emit(
        AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> logout() async {
    emit(state.copyWith(isLoading: true));
    await _repository.logout();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  Future<void> refreshProfile() async {
    try {
      final user = await _repository.fetchProfile();
      if (user != null) {
        emit(state.copyWith(user: user));
      }
    } catch (_) {}
  }

  Future<void> signInWithGoogle(
    String idToken, {
    required String turnstileToken,
  }) async {
    emit(
      const AuthState(
        status: AuthStatus.unauthenticated,
        isLoading: true,
      ),
    );
    try {
      final user = await _repository.signInWithGoogleIdToken(
        idToken,
        turnstileToken: turnstileToken,
      );
      emit(AuthState(status: AuthStatus.authenticated, user: user));
    } on Failure catch (f) {
      emit(
        AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: f.message,
        ),
      );
    } catch (e) {
      emit(
        AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> uploadAvatar(String filePath) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final user = await _repository.uploadAvatar(filePath);
      emit(AuthState(status: AuthStatus.authenticated, user: user));
    } on Failure catch (f) {
      emit(state.copyWith(isLoading: false, errorMessage: f.message));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  /// Sets [AuthUser.organization] to an org id the user belongs to (server
  /// validates via memberships).
  Future<void> switchActiveOrganization(String organizationId) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final user = await _repository.updateProfile({
        'organization': organizationId,
      });
      emit(AuthState(status: AuthStatus.authenticated, user: user));
    } on Failure catch (f) {
      emit(state.copyWith(isLoading: false, errorMessage: f.message));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> updateProfileFields({
    String? firstName,
    String? lastName,
    String? phone,
    bool? showRealName,
    bool? showPhoneNumber,
    bool? showEmail,
    String? dateOfBirth,
    String? sex,
    bool? twoFactorEnabled,
  }) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final user = await _repository.updateProfile({
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
        if (phone != null) 'phone': phone,
        if (showRealName != null) 'show_real_name': showRealName,
        if (showPhoneNumber != null) 'show_phone_number': showPhoneNumber,
        if (showEmail != null) 'show_email': showEmail,
        if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
        if (sex != null) 'sex': sex,
        if (twoFactorEnabled != null) 'two_factor_enabled': twoFactorEnabled,
      });
      emit(AuthState(status: AuthStatus.authenticated, user: user));
    } on Failure catch (f) {
      emit(state.copyWith(isLoading: false, errorMessage: f.message));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> submitVerification({
    required String idDocumentPath,
    required String selfieDocumentPath,
  }) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final user = await _repository.submitVerification(
        idDocumentPath: idDocumentPath,
        selfieDocumentPath: selfieDocumentPath,
      );
      emit(AuthState(status: AuthStatus.authenticated, user: user));
    } on Failure catch (f) {
      emit(state.copyWith(isLoading: false, errorMessage: f.message));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> refreshTrustAlias() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final user = await _repository.fetchOrCreateTrustAlias();
      emit(AuthState(status: AuthStatus.authenticated, user: user));
    } on Failure catch (f) {
      emit(state.copyWith(isLoading: false, errorMessage: f.message));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> regenerateTrustAlias() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final user = await _repository.regenerateTrustAlias();
      emit(AuthState(status: AuthStatus.authenticated, user: user));
    } on Failure catch (f) {
      emit(state.copyWith(isLoading: false, errorMessage: f.message));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<AuthMetadata> fetchMetadata() => _repository.fetchMetadata();

  Future<void> acceptLegal({
    required String acceptedTermsVersion,
    required String acceptedPrivacyVersion,
  }) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final user = await _repository.acceptLegal(
        acceptedTermsVersion: acceptedTermsVersion,
        acceptedPrivacyVersion: acceptedPrivacyVersion,
      );
      emit(AuthState(status: AuthStatus.authenticated, user: user));
    } on Failure catch (f) {
      emit(state.copyWith(isLoading: false, errorMessage: f.message));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<({String challengeId, String emailHint})> sendEmailVerification() {
    return _repository.sendEmailVerification();
  }

  Future<void> verifyEmail({
    required String challengeId,
    required String code,
  }) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final user = await _repository.verifyEmail(
        challengeId: challengeId,
        code: code,
      );
      emit(AuthState(status: AuthStatus.authenticated, user: user));
    } on Failure catch (f) {
      emit(state.copyWith(isLoading: false, errorMessage: f.message));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  void clearError() {
    emit(state.copyWith(clearError: true));
  }
}
