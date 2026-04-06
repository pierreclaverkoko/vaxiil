import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';

class SecureStorageService {

  SecureStorageService()
      : _storage = const FlutterSecureStorage(
          aOptions: _androidOptions,
        );
  final FlutterSecureStorage _storage;
  
  // Use different storage configs for different platforms
  static const AndroidOptions _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );
  
  static const IOSOptions _iosOptions = IOSOptions(
    
  );

  // Write operations
  Future<void> writeString(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      throw StorageFailure.writeError();
    }
  }

  Future<void> writeInt(String key, int value) async {
    try {
      await _storage.write(key: key, value: value.toString());
    } catch (e) {
      throw StorageFailure.writeError();
    }
  }

  Future<void> writeDouble(String key, double value) async {
    try {
      await _storage.write(key: key, value: value.toString());
    } catch (e) {
      throw StorageFailure.writeError();
    }
  }

  Future<void> writeBool(String key, bool value) async {
    try {
      await _storage.write(key: key, value: value.toString());
    } catch (e) {
      throw StorageFailure.writeError();
    }
  }

  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    try {
      final jsonString = jsonEncode(value);
      await _storage.write(key: key, value: jsonString);
    } catch (e) {
      throw StorageFailure.writeError();
    }
  }

  Future<void> writeList(String key, List<dynamic> value) async {
    try {
      final jsonString = jsonEncode(value);
      await _storage.write(key: key, value: jsonString);
    } catch (e) {
      throw StorageFailure.writeError();
    }
  }

  // Read operations
  Future<String?> readString(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      throw StorageFailure.readError();
    }
  }

  Future<int?> readInt(String key) async {
    try {
      final value = await _storage.read(key: key);
      return value != null ? int.tryParse(value) : null;
    } catch (e) {
      throw StorageFailure.readError();
    }
  }

  Future<double?> readDouble(String key) async {
    try {
      final value = await _storage.read(key: key);
      return value != null ? double.tryParse(value) : null;
    } catch (e) {
      throw StorageFailure.readError();
    }
  }

  Future<bool?> readBool(String key) async {
    try {
      final value = await _storage.read(key: key);
      return value != null ? value.toLowerCase() == 'true' : null;
    } catch (e) {
      throw StorageFailure.readError();
    }
  }

  Future<Map<String, dynamic>?> readMap(String key) async {
    try {
      final value = await _storage.read(key: key);
      if (value == null) return null;
      
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw StorageFailure.dataCorrupted();
    } catch (e) {
      if (e is StorageFailure) rethrow;
      throw StorageFailure.readError();
    }
  }

  Future<List<dynamic>?> readList(String key) async {
    try {
      final value = await _storage.read(key: key);
      if (value == null) return null;
      
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded;
      }
      throw StorageFailure.dataCorrupted();
    } catch (e) {
      if (e is StorageFailure) rethrow;
      throw StorageFailure.readError();
    }
  }

  // Check if key exists
  Future<bool> containsKey(String key) async {
    try {
      final value = await _storage.read(key: key);
      return value != null;
    } catch (e) {
      throw StorageFailure.readError();
    }
  }

  // Delete operations
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      throw StorageFailure.deleteError();
    }
  }

  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      throw StorageFailure.deleteError();
    }
  }

  // Get all keys
  Future<List<String>> getAllKeys() async {
    try {
      return await _storage.readAll().then((data) => data.keys.toList());
    } catch (e) {
      throw StorageFailure.readError();
    }
  }

  // Clear all data
  Future<void> clear() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      throw StorageFailure.deleteError();
    }
  }

  // Utility methods for common operations
  
  // Authentication tokens
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      writeString('access_token', accessToken),
      writeString('refresh_token', refreshToken),
    ]);
  }

  Future<Map<String, String?>> getTokens() async {
    final accessToken = await readString('access_token');
    final refreshToken = await readString('refresh_token');
    
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
    };
  }

  Future<void> clearTokens() async {
    await Future.wait([
      delete('access_token'),
      delete('refresh_token'),
    ]);
  }

  // User preferences
  Future<void> saveTheme(String theme) async {
    await writeString('theme', theme);
  }

  Future<String?> getTheme() async {
    return readString('theme');
  }

  Future<void> saveLanguage(String language) async {
    await writeString('language', language);
  }

  Future<String?> getLanguage() async {
    return readString('language');
  }

  // User session
  Future<void> saveUserSession(Map<String, dynamic> userData) async {
    await writeMap('user_session', userData);
  }

  Future<Map<String, dynamic>?> getUserSession() async {
    return readMap('user_session');
  }

  Future<void> clearUserSession() async {
    await delete('user_session');
  }

  // Business context
  Future<void> saveCurrentBusiness(String businessId) async {
    await writeString('current_business', businessId);
  }

  Future<String?> getCurrentBusiness() async {
    return readString('current_business');
  }

  Future<void> clearCurrentBusiness() async {
    await delete('current_business');
  }

  // Biometric settings
  Future<void> saveBiometricEnabled(bool enabled) async {
    await writeBool('biometric_enabled', enabled);
  }

  Future<bool> isBiometricEnabled() async {
    return await readBool('biometric_enabled') ?? false;
  }

  // First launch check
  Future<void> setFirstLaunchComplete() async {
    await writeBool('first_launch_complete', true);
  }

  Future<bool> isFirstLaunch() async {
    final isFirst = await readBool('first_launch_complete');
    return isFirst != true; // Return true if not set or false
  }

  // Onboarding completion
  Future<void> setOnboardingComplete() async {
    await writeBool('onboarding_complete', true);
  }

  Future<bool> isOnboardingComplete() async {
    return await readBool('onboarding_complete') ?? false;
  }

  // Notification preferences
  Future<void> saveNotificationPreferences(Map<String, bool> preferences) async {
    await writeMap('notification_preferences', preferences);
  }

  Future<Map<String, bool>?> getNotificationPreferences() async {
    final prefs = await readMap('notification_preferences');
    if (prefs == null) return null;
    
    // Convert all values to bool
    return prefs.map((key, value) => MapEntry(key, value as bool));
  }
}
