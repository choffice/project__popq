import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PopqThemePreference {
  light,
  dark,
}

class PopqThemeController extends ChangeNotifier {
  PopqThemeController({
    String storageKey = 'popq.theme.preference.v1',
  }) : _storageKey = storageKey;

  final String _storageKey;

  PopqThemePreference _preference = PopqThemePreference.light;
  bool _restored = false;

  PopqThemePreference get preference => _preference;

  bool get restored => _restored;

  bool get isDarkMode {
    return _preference == PopqThemePreference.dark;
  }

  ThemeMode get themeMode {
    return switch (_preference) {
      PopqThemePreference.light => ThemeMode.light,
      PopqThemePreference.dark => ThemeMode.dark,
    };
  }

  Future<void> restore() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final savedValue = preferences.getString(_storageKey);

      _preference = switch (savedValue) {
        'dark' => PopqThemePreference.dark,
        _ => PopqThemePreference.light,
      };
    } catch (_) {
      _preference = PopqThemePreference.light;
    } finally {
      _restored = true;
      notifyListeners();
    }
  }

  Future<void> setPreference(
      PopqThemePreference preference,
      ) async {
    if (_preference == preference) {
      return;
    }

    final previousPreference = _preference;

    _preference = preference;
    notifyListeners();

    try {
      final preferences = await SharedPreferences.getInstance();

      await preferences.setString(
        _storageKey,
        preference.name,
      );
    } catch (_) {
      _preference = previousPreference;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> useLightMode() {
    return setPreference(PopqThemePreference.light);
  }

  Future<void> useDarkMode() {
    return setPreference(PopqThemePreference.dark);
  }

  Future<void> setDarkMode(bool enabled) {
    return setPreference(
      enabled
          ? PopqThemePreference.dark
          : PopqThemePreference.light,
    );
  }
}