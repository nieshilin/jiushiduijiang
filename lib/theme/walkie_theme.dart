import 'package:flutter/material.dart';

/// 现代对讲机 App 主题 — 深色背景 + 荧光绿强调色
class WalkieTheme {
  WalkieTheme._();

  // 背景
  static const Color background = Color(0xFF050505);
  static const Color surface = Color(0xFF0F0F0F);
  static const Color surfaceElevated = Color(0xFF1A1A1A);
  static const Color card = Color(0xFF141414);

  // 强调色 — 荧光绿
  static const Color accent = Color(0xFFBFFF00);
  static const Color accentDim = Color(0xFF8FB300);
  static const Color accentDark = Color(0xFF5A7200);
  static const Color accentGlow = Color(0xFFBFFF00);

  // 状态色
  static const Color txRed = Color(0xFFFF3B30);
  static const Color rxGreen = Color(0xFFBFFF00);
  static const Color online = Color(0xFF34C759);

  // 文字
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textMuted = Color(0xFF5C5C60);
  static const Color lcdText = Color(0xFF1A2E00);
  static const Color lcdTextDim = Color(0xFF3D5C00);

  // LCD 屏幕
  static const Color lcdBg = Color(0xFFBFFF00);
  static const Color lcdBgDim = Color(0xFFA8D600);

  // 边框
  static const Color border = Color(0xFF2A2A2A);
  static const Color divider = Color(0xFF1F1F1F);

  // PTT 按钮
  static const Color pttRing = Color(0xFFBFFF00);
  static const Color pttInner = Color(0xFF0F0F0F);
  static const Color pttPressed = Color(0xFFBFFF00);

  // 字体
  static const String fontMono = 'RobotoMono';
  static const String fontDisplay = 'Roboto';

  // 渐变
  static const LinearGradient lcdGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFC8FF1A),
      Color(0xFFB8E600),
      Color(0xFFA8D600),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient pttGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1A1A1A),
      Color(0xFF0A0A0A),
    ],
  );

  // 阴影
  static List<BoxShadow> get lcdShadow => [
    BoxShadow(
      color: const Color(0xFFBFFF00).withValues(alpha: 0.25),
      blurRadius: 30,
      spreadRadius: 2,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.5),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> pttGlow(bool active) => [
    if (active)
      BoxShadow(
        color: const Color(0xFFBFFF00).withValues(alpha: 0.45),
        blurRadius: 45,
        spreadRadius: 8,
      ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.6),
      blurRadius: 25,
      offset: const Offset(0, 12),
    ),
  ];

  // 主题数据
  static ThemeData get themeData => ThemeData.dark().copyWith(
    scaffoldBackgroundColor: background,
    primaryColor: accent,
    colorScheme: const ColorScheme.dark(
      primary: accent,
      secondary: accent,
      surface: surface,
      onPrimary: lcdText,
      onSurface: textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: border),
      ),
    ),
  );
}
