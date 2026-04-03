import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/features/auth/data/auth_repository.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repository) : super(const AuthState(status: AuthStatus.unknown));

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

  Future<void> login({required String email, required String password}) async {
    emit(AuthState(
      status: AuthStatus.unauthenticated,
      isLoading: true,
    ));
    try {
      final user = await _repository.login(email: email, password: password);
      emit(AuthState(status: AuthStatus.authenticated, user: user));
    } on Failure catch (f) {
      emit(AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: f.message,
      ));
    } catch (e) {
      emit(AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> register({
    required String email,
    required String username,
    required String password,
    required String passwordConfirm,
    String? firstName,
    String? lastName,
  }) async {
    emit(const AuthState(
      status: AuthStatus.unauthenticated,
      isLoading: true,
    ));
    try {
      final user = await _repository.register(
        email: email,
        username: username,
        password: password,
        passwordConfirm: passwordConfirm,
        firstName: firstName,
        lastName: lastName,
      );
      emit(AuthState(status: AuthStatus.authenticated, user: user));
    } on Failure catch (f) {
      emit(AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: f.message,
      ));
    } catch (e) {
      emit(AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: e.toString(),
      ));
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

  Future<void> signInWithGoogle(String idToken) async {
    emit(const AuthState(
      status: AuthStatus.unauthenticated,
      isLoading: true,
    ));
    try {
      final user = await _repository.signInWithGoogleIdToken(idToken);
      emit(AuthState(status: AuthStatus.authenticated, user: user));
    } on Failure catch (f) {
      emit(AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: f.message,
      ));
    } catch (e) {
      emit(AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: e.toString(),
      ));
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

  Future<void> updateProfileFields({
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final user = await _repository.updateProfile({
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
        if (phone != null) 'phone': phone,
      });
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
