import 'package:flutter/material.dart';
import 'package:vaxiil_mobile/core/storage/secure_storage_service.dart';

/// Persisted app locale (`en` / `fr`). Used for UI catalogs and Accept-Language.
class LocaleManager extends ChangeNotifier {
  factory LocaleManager() => _instance;
  LocaleManager._internal();
  static final LocaleManager _instance = LocaleManager._internal();

  static const supportedLanguageCodes = ['en', 'fr'];

  final SecureStorageService _storage = SecureStorageService();
  Locale _locale = const Locale('en');
  bool _isInitialized = false;

  Locale get locale => _locale;
  String get languageCode => _locale.languageCode;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;
    final saved = await _storage.getLanguage();
    if (saved != null && supportedLanguageCodes.contains(saved)) {
      _locale = Locale(saved);
    }
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setLanguageCode(String code) async {
    if (!supportedLanguageCodes.contains(code)) return;
    if (_locale.languageCode == code) return;
    _locale = Locale(code);
    await _storage.saveLanguage(code);
    notifyListeners();
  }
}
