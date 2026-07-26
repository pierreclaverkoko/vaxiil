import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:vaxiil_mobile/core/constants/app_constants.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/core/network/dio_client.dart';
import 'package:vaxiil_mobile/core/storage/secure_storage_service.dart';
import 'package:vaxiil_mobile/features/auth/data/auth_metadata_models.dart';
import 'package:vaxiil_mobile/features/auth/data/login_result.dart';
import 'package:vaxiil_mobile/features/auth/domain/entities/auth_user.dart';

class AuthRepository {
  AuthRepository({
    required DioClient dioClient,
    required SecureStorageService storage,
  })  : _dio = dioClient.dio,
        _storage = storage;

  final Dio _dio;
  final SecureStorageService _storage;

  Future<LoginResult> login({
    required String email,
    required String password,
    required String turnstileToken,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        AppConstants.authLoginPath,
        data: {
          'email': email,
          'password': password,
          'cf_turnstile_response': turnstileToken,
        },
      );
      final data = response.data ?? {};
      if (data['requires_otp'] == true) {
        return LoginOtpChallengeResult(
          challengeId: data['challenge_id']?.toString() ?? '',
          emailHint: data['email_hint']?.toString() ?? email,
        );
      }
      return LoginSessionResult(await _persistSession(data));
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<AuthUser> verifyLoginOtp({
    required String challengeId,
    required String code,
    required String turnstileToken,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        AppConstants.authLoginVerifyOtpPath,
        data: {
          'challenge_id': challengeId,
          'code': code,
          'cf_turnstile_response': turnstileToken,
        },
      );
      return await _persistSession(response.data!);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  /// Authenticated: send OTP for [purpose] (`password_change` or `login`).
  Future<({String challengeId, String emailHint})> sendOtp({
    required String purpose,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        AppConstants.authOtpSendPath,
        data: {'purpose': purpose},
      );
      final data = response.data ?? {};
      return (
        challengeId: data['challenge_id']?.toString() ?? '',
        emailHint: data['email_hint']?.toString() ?? '',
      );
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String challengeId,
    required String code,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        AppConstants.authPasswordChangePath,
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
          'challenge_id': challengeId,
          'code': code,
        },
      );
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<String?> requestPasswordReset({
    required String email,
    required String turnstileToken,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        AppConstants.authPasswordResetRequestPath,
        data: {
          'email': email,
          'cf_turnstile_response': turnstileToken,
        },
      );
      final id = response.data?['challenge_id'];
      return id is String ? id : null;
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<void> confirmPasswordReset({
    required String email,
    required String challengeId,
    required String code,
    required String newPassword,
    required String turnstileToken,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        AppConstants.authPasswordResetConfirmPath,
        data: {
          'email': email,
          'challenge_id': challengeId,
          'code': code,
          'new_password': newPassword,
          'cf_turnstile_response': turnstileToken,
        },
      );
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<AuthUser> register({
    required String email,
    required String username,
    required String password,
    required String passwordConfirm,
    required String acceptedTermsVersion,
    required String acceptedPrivacyVersion,
    required String turnstileToken,
    String? firstName,
    String? lastName,
    String? phone,
    String role = 'CLIENT',
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        AppConstants.authRegisterPath,
        data: {
          'email': email,
          'username': username,
          'password': password,
          'password_confirm': passwordConfirm,
          'first_name': firstName ?? '',
          'last_name': lastName ?? '',
          'phone': phone ?? '',
          'role': role,
          'accepted_terms_version': acceptedTermsVersion,
          'accepted_privacy_version': acceptedPrivacyVersion,
          'cf_turnstile_response': turnstileToken,
        },
      );
      return await _persistSession(response.data!);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<AuthMetadata> fetchMetadata() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        AppConstants.authMetadataPath,
      );
      return AuthMetadata.fromJson(response.data ?? {});
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<AuthUser> acceptLegal({
    required String acceptedTermsVersion,
    required String acceptedPrivacyVersion,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        AppConstants.authAcceptLegalPath,
        data: {
          'accepted_terms_version': acceptedTermsVersion,
          'accepted_privacy_version': acceptedPrivacyVersion,
        },
      );
      final user = AuthUser.fromJson(response.data!);
      await _storage.writeMap(AppConstants.userProfileKey, user.toJson());
      await _syncCurrentBusiness(user);
      return user;
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<({String challengeId, String emailHint})> sendEmailVerification() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        AppConstants.authEmailVerifySendPath,
        data: {},
      );
      final data = response.data ?? {};
      return (
        challengeId: data['challenge_id']?.toString() ?? '',
        emailHint: data['email_hint'] as String? ?? '',
      );
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<AuthUser> verifyEmail({
    required String challengeId,
    required String code,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        AppConstants.authEmailVerifyPath,
        data: {
          'challenge_id': challengeId,
          'code': code,
        },
      );
      final user = AuthUser.fromJson(response.data!);
      await _storage.writeMap(AppConstants.userProfileKey, user.toJson());
      await _syncCurrentBusiness(user);
      return user;
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<void> logout() async {
    final refresh = await _storage.readString(AppConstants.refreshTokenKey);
    try {
      if (refresh != null && refresh.isNotEmpty) {
        await _dio.post<void>(
          AppConstants.authLogoutPath,
          data: {'refresh': refresh},
        );
      }
    } on DioException {
      // Still clear local session
    } finally {
      await _storage.clearTokens();
      await _storage.delete(AppConstants.userProfileKey);
      await _storage.clearCurrentBusiness();
    }
  }

  Future<AuthUser?> loadCachedUser() async {
    final map = await _storage.readMap(AppConstants.userProfileKey);
    if (map == null) return null;
    try {
      return AuthUser.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<AuthUser?> fetchProfile() async {
    try {
      final response =
          await _dio.get<Map<String, dynamic>>(AppConstants.authProfilePath);
      final data = response.data;
      if (data == null) return null;
      final user = AuthUser.fromJson(data);
      await _storage.writeMap(AppConstants.userProfileKey, user.toJson());
      await _syncCurrentBusiness(user);
      return user;
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<bool> hasStoredTokens() async {
    final access = await _storage.readString(AppConstants.accessTokenKey);
    return access != null && access.isNotEmpty;
  }

  Future<AuthUser?> restoreSession() async {
    if (!await hasStoredTokens()) return null;
    final cached = await loadCachedUser();
    try {
      final fresh = await fetchProfile();
      return fresh ?? cached;
    } catch (_) {
      return cached;
    }
  }

  Future<AuthUser> signInWithGoogleIdToken(
    String idToken, {
    required String turnstileToken,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        AppConstants.authGooglePath,
        data: {
          'id_token': idToken,
          'cf_turnstile_response': turnstileToken,
        },
      );
      return await _persistSession(response.data!);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<AuthUser> uploadAvatar(String filePath) async {
    if (kIsWeb) {
      throw const NetworkFailure(
        message: 'Avatar upload is not supported on web in this build',
        code: 'NOT_SUPPORTED',
      );
    }
    try {
      final form = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(filePath),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        AppConstants.authAvatarPath,
        data: form,
      );
      final user = AuthUser.fromJson(response.data!);
      await _storage.writeMap(AppConstants.userProfileKey, user.toJson());
      await _syncCurrentBusiness(user);
      return user;
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<AuthUser> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        AppConstants.authProfilePath,
        data: data,
      );
      final user = AuthUser.fromJson(response.data!);
      await _storage.writeMap(AppConstants.userProfileKey, user.toJson());
      await _syncCurrentBusiness(user);
      return user;
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<AuthUser> submitVerification({
    required String idDocumentPath,
    required String selfieDocumentPath,
  }) async {
    if (kIsWeb) {
      throw const NetworkFailure(
        message: 'Verification upload is not supported on web in this build',
        code: 'NOT_SUPPORTED',
      );
    }
    try {
      final form = FormData.fromMap({
        'id_document': await MultipartFile.fromFile(idDocumentPath),
        'selfie_document': await MultipartFile.fromFile(selfieDocumentPath),
      });
      await _dio.post<void>(AppConstants.authVerifyPath, data: form);
      final user = await fetchProfile();
      if (user == null) {
        throw const NetworkFailure(
          message: 'Could not refresh profile after verification',
          code: 'AUTH_INVALID_RESPONSE',
        );
      }
      return user;
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<AuthUser> fetchOrCreateTrustAlias() async {
    try {
      await _dio.get<Map<String, dynamic>>(AppConstants.authGenerateAliasPath);
      final user = await fetchProfile();
      if (user == null) {
        throw const NetworkFailure(
          message: 'Could not refresh profile after generating alias',
          code: 'AUTH_INVALID_RESPONSE',
        );
      }
      return user;
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<AuthUser> regenerateTrustAlias() async {
    try {
      await _dio
          .post<Map<String, dynamic>>(AppConstants.authRegenerateAliasPath);
      final user = await fetchProfile();
      if (user == null) {
        throw const NetworkFailure(
          message: 'Could not refresh profile after regenerating alias',
          code: 'AUTH_INVALID_RESPONSE',
        );
      }
      return user;
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<AuthUser> _persistSession(Map<String, dynamic> data) async {
    final access = data['access'] as String?;
    final refresh = data['refresh'] as String?;
    final userMap = data['user'] as Map<String, dynamic>?;
    if (access == null || refresh == null || userMap == null) {
      throw const NetworkFailure(
        message: 'Invalid authentication response',
        code: 'AUTH_INVALID_RESPONSE',
      );
    }
    final user = AuthUser.fromJson(userMap);
    await _storage.saveTokens(accessToken: access, refreshToken: refresh);
    await _storage.writeMap(AppConstants.userProfileKey, user.toJson());
    await _syncCurrentBusiness(user);
    return user;
  }

  Future<void> _syncCurrentBusiness(AuthUser user) async {
    final id = user.organization;
    if (id != null && id.isNotEmpty) {
      await _storage.saveCurrentBusiness(id);
    }
  }

  Failure _mapDio(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String) {
        return NetworkFailure.unauthorized(message: detail);
      }
      final nonField = data['non_field_errors'];
      if (nonField is List && nonField.isNotEmpty) {
        return NetworkFailure.badRequest(message: nonField.first.toString());
      }
      for (final value in data.values) {
        if (value is List && value.isNotEmpty) {
          return NetworkFailure.badRequest(message: value.first.toString());
        }
        if (value is String && value.isNotEmpty) {
          return NetworkFailure.badRequest(message: value);
        }
      }
    }
    final msg = e.message ?? 'Network error';
    return NetworkFailure.unknown(message: msg);
  }
}
