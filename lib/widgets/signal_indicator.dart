import 'package:flutter/material.dart';
import 'package:jiudhiduijiang/theme/walkie_theme.dart';

/// 信号质量指示器 — 4 格竖条
class SignalIndicator extends StatelessWidget {
  /// 信号质量 0~4
  final int quality;

  /// 是否使用 LCD 风格（绿色 LCD 屏幕上用）
  final bool lcdStyle;

  /// 尺寸
  final double size;

  const SignalIndicator({
    super.key,
    required this.quality,
    this.lcdStyle = false,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = lcdStyle ? WalkieTheme.lcdText : WalkieTheme.accent;
    final inactiveColor = lcdStyle
        ? WalkieTheme.lcdTextDim
        : WalkieTheme.textMuted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final isActive = i < quality;
        return Container(
          width: size * 0.22,
          height: size * (0.3 + i * 0.22),
          margin: EdgeInsets.only(right: i < 3 ? size * 0.08 : 0),
          decoration: BoxDecoration(
            color: isActive ? activeColor : inactiveColor.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}
