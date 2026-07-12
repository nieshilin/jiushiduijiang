import 'package:flutter/material.dart';
import 'package:jiudhiduijiang/theme/walkie_theme.dart';

/// 音量滑动调节控件 + 静音按钮
class VolumeControl extends StatelessWidget {
  final double volume;
  final bool isMuted;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onMuteToggle;

  const VolumeControl({
    super.key,
    required this.volume,
    required this.isMuted,
    required this.onVolumeChanged,
    required this.onMuteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: WalkieTheme.surfaceMid,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WalkieTheme.border),
      ),
      child: Row(
        children: [
          // 静音按钮
          GestureDetector(
            onTap: onMuteToggle,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isMuted
                    ? WalkieTheme.ledRed.withValues(alpha: 0.2)
                    : WalkieTheme.surfaceLight,
                border: Border.all(
                  color: isMuted ? WalkieTheme.ledRed : WalkieTheme.border,
                  width: 1.5,
                ),
              ),
              child: Icon(
                isMuted ? Icons.volume_off : Icons.volume_up,
                size: 18,
                color: isMuted ? WalkieTheme.ledRed : WalkieTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 音量标签
          Text(
            'VOL',
            style: TextStyle(
              fontFamily: WalkieTheme.fontMono,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: WalkieTheme.textSecondary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 8),
          // 音量滑块
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbColor: WalkieTheme.ledGreen,
                activeTrackColor: WalkieTheme.ledGreen.withValues(alpha: 0.6),
                inactiveTrackColor: WalkieTheme.surfaceLight,
                overlayColor: WalkieTheme.ledGreen.withValues(alpha: 0.1),
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 8),
                trackShape: const RoundedRectSliderTrackShape(),
              ),
              child: Slider(
                value: volume,
                min: 0.0,
                max: 1.0,
                onChanged: isMuted ? null : onVolumeChanged,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 音量数值
          SizedBox(
            width: 36,
            child: Text(
              '${(volume * 100).round()}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: WalkieTheme.fontMono,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isMuted
                    ? WalkieTheme.ledRed
                    : WalkieTheme.ledScreenText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
