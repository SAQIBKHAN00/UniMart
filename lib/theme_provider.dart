import 'package:flutter/material.dart';

class ThemeProvider {
  static final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(
    ThemeMode.light,
  );

  static bool get isDarkMode => themeModeNotifier.value == ThemeMode.dark;

  static void toggleTheme() {
    themeModeNotifier.value =
        themeModeNotifier.value == ThemeMode.light
            ? ThemeMode.dark
            : ThemeMode.light;
  }

  static void setThemeMode(ThemeMode mode) {
    themeModeNotifier.value = mode;
  }
}
