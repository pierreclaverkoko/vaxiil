import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:vaxiil_mobile/core/constants/app_constants.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/core/network/dio_client.dart';
import 'package:vaxiil_mobile/core/storage/secure_storage_service.dart';
import 'package:vaxiil_mobile/features/auth/domain/entities/auth_user.dart';

class AuthRepository {
  AuthRepository({
    required DioClient dioClient,
    required SecureStorageService storage,
  })  : _dio = dioClient.dio,
        _storage = storage;

  final Dio _dio;
  final SecureStorageService _storage;

  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        AppConstants.authLoginPath,
        data: {'email': email, 'password': password},
      );
      return await _persistSession(response.data!);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<AuthUser> register({
    required String email,
    required String username,
    required String password,
    required String passwordConfirm,
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
        },
      );
      return await _persistSession(response.data!);
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
      final response = await _dio.get<Map<String, dynamic>>(AppConstants.authProfilePath);
      final data = response.data;
      if (data == null) return null;
      final user = AuthUser.fromJson(data);
      await _storage.writeMap(AppConstants.userProfileKey, user.toJson());
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

  Future<AuthUser> signInWithGoogleIdToken(String idToken) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        AppConstants.authGooglePath,
        data: {'id_token': idToken},
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
    return user;
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
