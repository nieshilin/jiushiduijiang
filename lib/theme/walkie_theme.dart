import 'package:flutter/material.dart';

/// 硬核对讲机深色主题
class WalkieTheme {
  WalkieTheme._();

  // ── 核心色板 ──
  static const Color background = Color(0xFF0A0A0A);
  static const Color surfaceDark = Color(0xFF141414);
  static const Color surfaceMid = Color(0xFF1E1E1E);
  static const Color surfaceLight = Color(0xFF2A2A2A);
  static const Color border = Color(0xFF333333);

  // ── 指示灯配色（复古） ──
  static const Color ledGreen = Color(0xFF00FF41);
  static const Color ledRed = Color(0xFFFF1744);
  static const Color ledAmber = Color(0xFFFFAB00);
  static const Color ledBlue = Color(0xFF2979FF);
  static const Color ledDim = Color(0xFF1B3A1B);

  // ── LED 显示屏 ──
  static const Color ledScreenBg = Color(0xFF001100);
  static const Color ledScreenText = Color(0xFF00FF41);
  static const Color ledScreenDim = Color(0xFF003311);

  // ── 文字 ──
  static const Color textPrimary = Color(0xFFE0E0E0);
  static const Color textSecondary = Color(0xFF888888);
  static const Color textDim = Color(0xFF555555);

  // ── PTT 按钮 ──
  static const Color pttIdle = Color(0xFF2A2A2A);
  static const Color pttPressed = Color(0xFFFF1744);
  static const Color pttGlow = Color(0x66FF1744);

  // ── 字体 ──
  static const String fontMono = 'Courier';
  static const String fontDisplay = 'Courier';

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: ledGreen,
        secondary: ledAmber,
        surface: surfaceDark,
        error: ledRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textSecondary),
        bodySmall: TextStyle(color: textDim),
      ),
      dividerColor: border,
    );
  }
}
