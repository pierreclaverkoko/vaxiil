import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:heroicons/heroicons.dart';
import 'package:vaxiil_mobile/core/storage/secure_storage_service.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';

enum ThemeModeOption {
  light,
  dark,
  system,
}

class ThemeManager extends ChangeNotifier {
  factory ThemeManager() => _instance;
  ThemeManager._internal();
  static final ThemeManager _instance = ThemeManager._internal();
  
  final SecureStorageService _storage = SecureStorageService();
  ThemeModeOption _themeMode = ThemeModeOption.system;
  bool _isInitialized = false;
  
  // Getters
  ThemeModeOption get themeMode => _themeMode;
  bool get isInitialized => _isInitialized;
  
  // Get current theme mode (ThemeMode for MaterialApp)
  ThemeMode get currentThemeMode {
    switch (_themeMode) {
      case ThemeModeOption.light:
        return ThemeMode.light;
      case ThemeModeOption.dark:
        return ThemeMode.dark;
      case ThemeModeOption.system:
        return ThemeMode.system;
    }
  }
  
  // Get current theme data
  ThemeData get currentThemeData {
    switch (_themeMode) {
      case ThemeModeOption.light:
        return AppTheme.lightTheme;
      case ThemeModeOption.dark:
        return AppTheme.darkTheme;
      case ThemeModeOption.system:
        final brightness = SchedulerBinding.instance.platformDispatcher.platformBrightness;
        return brightness == Brightness.dark ? AppTheme.darkTheme : AppTheme.lightTheme;
    }
  }
  
  // Check if current theme is dark
  bool get isDarkTheme {
    switch (_themeMode) {
      case ThemeModeOption.light:
        return false;
      case ThemeModeOption.dark:
        return true;
      case ThemeModeOption.system:
        final brightness = SchedulerBinding.instance.platformDispatcher.platformBrightness;
        return brightness == Brightness.dark;
    }
  }
  
  // Initialize theme manager
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final savedTheme = await _storage.readString('theme');
      if (savedTheme != null) {
        _themeMode = _parseThemeMode(savedTheme);
      }
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      // If there's an error, use system theme as default
      _themeMode = ThemeModeOption.system;
      _isInitialized = true;
      notifyListeners();
    }
  }
  
  // Set theme mode
  Future<void> setThemeMode(ThemeModeOption mode) async {
    if (_themeMode == mode) return;
    
    try {
      _themeMode = mode;
      await _storage.writeString('theme', mode.name);
      notifyListeners();
    } catch (e) {
      // Revert change if storage fails
      _themeMode = _themeMode == ThemeModeOption.light 
          ? ThemeModeOption.dark 
          : ThemeModeOption.light;
      notifyListeners();
    }
  }
  
  // Toggle between light and dark
  Future<void> toggleTheme() async {
    final newMode = _themeMode == ThemeModeOption.light 
        ? ThemeModeOption.dark 
        : ThemeModeOption.light;
    await setThemeMode(newMode);
  }
  
  // Parse theme mode from string
  ThemeModeOption _parseThemeMode(String themeString) {
    switch (themeString.toLowerCase()) {
      case 'light':
        return ThemeModeOption.light;
      case 'dark':
        return ThemeModeOption.dark;
      case 'system':
      default:
        return ThemeModeOption.system;
    }
  }
  
  // Get theme mode display name
  String getThemeModeDisplayName(ThemeModeOption mode) {
    switch (mode) {
      case ThemeModeOption.light:
        return 'Light';
      case ThemeModeOption.dark:
        return 'Dark';
      case ThemeModeOption.system:
        return 'System';
    }
  }
  
  // Get available theme options
  List<ThemeModeOption> get availableThemeModes => ThemeModeOption.values;
  
  // Listen to system theme changes
  void listenToSystemThemeChanges() {
    SchedulerBinding.instance.platformDispatcher.onPlatformBrightnessChanged = () {
      if (_themeMode == ThemeModeOption.system) {
        notifyListeners();
      }
    };
  }
  
  // Get theme color based on current theme
  Color getThemeColor({
    required Color lightColor,
    required Color darkColor,
  }) {
    return isDarkTheme ? darkColor : lightColor;
  }
  
  // Get theme-specific colors
  Color get primaryColor => getThemeColor(
    lightColor: AppTheme.primaryColor,
    darkColor: AppTheme.primaryColor,
  );
  
  Color get backgroundColor => getThemeColor(
    lightColor: AppTheme.backgroundColor,
    darkColor: const Color(0xFF121212),
  );
  
  Color get surfaceColor => getThemeColor(
    lightColor: AppTheme.surfaceColor,
    darkColor: const Color(0xFF1E1E1E),
  );
  
  Color get cardColor => getThemeColor(
    lightColor: AppTheme.cardColor,
    darkColor: const Color(0xFF1E1E1E),
  );
  
  Color get textPrimaryColor => getThemeColor(
    lightColor: AppTheme.textPrimary,
    darkColor: const Color(0xFFFFFFFF),
  );
  
  Color get textSecondaryColor => getThemeColor(
    lightColor: AppTheme.textSecondary,
    darkColor: const Color(0xFF808080),
  );
  
  Color get borderColor => getThemeColor(
    lightColor: AppTheme.borderColor,
    darkColor: const Color(0xFF404040),
  );
  
  Color get dividerColor => getThemeColor(
    lightColor: AppTheme.dividerColor,
    darkColor: const Color(0xFF303030),
  );
  
  // Reset to system theme
  Future<void> resetToSystemTheme() async {
    await setThemeMode(ThemeModeOption.system);
  }
  
  // Dispose resources
}

// Theme manager provider
class ThemeManagerProvider extends InheritedWidget {
  
  const ThemeManagerProvider({
    required this.themeManager, required super.child, super.key,
  });
  final ThemeManager themeManager;
  
  static ThemeManager of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<ThemeManagerProvider>();
    return provider?.themeManager ?? ThemeManager();
  }
  
  @override
  bool updateShouldNotify(ThemeManagerProvider oldWidget) {
    return themeManager.themeMode != oldWidget.themeManager.themeMode;
  }
}

// Theme builder widget
class ThemeBuilder extends StatelessWidget {
  
  const ThemeBuilder({
    required this.builder, super.key,
  });
  final Widget Function(BuildContext context, ThemeData theme, bool isDark) builder;
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeManager(),
      builder: (context, child) {
        final themeManager = ThemeManagerProvider.of(context);
        return builder(
          context,
          themeManager.currentThemeData,
          themeManager.isDarkTheme,
        );
      },
    );
  }
}

// Theme mode selector widget
class ThemeModeSelector extends StatelessWidget {
  
  const ThemeModeSelector({
    super.key,
    this.onThemeChanged,
  });
  final Function(ThemeModeOption)? onThemeChanged;
  
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeManager(),
      builder: (context, child) {
        final themeManager = ThemeManagerProvider.of(context);
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Theme',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...ThemeModeOption.values.map((mode) {
              return RadioListTile<ThemeModeOption>(
                title: Text(themeManager.getThemeModeDisplayName(mode)),
                value: mode,
                groupValue: themeManager.themeMode,
                onChanged: (value) async {
                  if (value != null) {
                    await themeManager.setThemeMode(value);
                    onThemeChanged?.call(value);
                  }
                },
              );
            }),
          ],
        );
      },
    );
  }
}

// Theme toggle button
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});
  
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeManager(),
      builder: (context, child) {
        final themeManager = ThemeManagerProvider.of(context);
        final isDark = themeManager.isDarkTheme;
        
        return IconButton(
          onPressed: themeManager.toggleTheme,
          icon: HeroIcon(
            isDark ? HeroIcons.sun : HeroIcons.moon,
            style: HeroIconStyle.outline,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
        );
      },
    );
  }
}

// Theme-aware widget
class ThemeAwareWidget extends StatelessWidget {
  
  const ThemeAwareWidget({
    required this.builder, super.key,
  });
  final Widget Function(BuildContext context, bool isDarkTheme) builder;
  
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeManager(),
      builder: (context, child) {
        final themeManager = ThemeManagerProvider.of(context);
        return builder(context, themeManager.isDarkTheme);
      },
    );
  }
}
