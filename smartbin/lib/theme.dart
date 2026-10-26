import 'package:flutter/material.dart';

/// Same palette as the Python prototype.
class SB {
  static const bg = Color(0xFF151517);
  static const container = Color(0xFF303030);
  static const panel = Color(0xFF1C1C1F);
  static const border = Color(0xFF626267);
  static const text = Color(0xFFF5F5F7);
  static const muted = Color(0xFFD0D0D3);
  static const blue = Color(0xFF2468F2);
  static const red = Color(0xFFE04B4B);
  static const cover = Color(0xFF565656);
  static const black = Color(0xFF000000);
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: SB.bg,
    colorScheme: const ColorScheme.dark(primary: SB.blue, surface: SB.bg),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: SB.text),
  );
}
