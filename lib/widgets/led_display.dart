import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:jiudhiduijiang/theme/walkie_theme.dart';

/// 现代绿色 LCD 大屏 — 显示在线人数、设备名、讲话者
class LedDisplay extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  final int onlineCount;
  final String speakerText;
  final String statusSubtext;
  final bool isTransmitting;
  final bool isReceiving;
  final bool isConnected;

  const LedDisplay({
    super.key,
    required this.deviceId,
    required this.deviceName,
    required this.onlineCount,
    required this.speakerText,
    required this.statusSubtext,
    required this.isTransmitting,
    required this.isReceiving,
    required this.isConnected,
  });

  @override
  State<LedDisplay> createState() => _LedDisplayState();
}

class _LedDisplayState extends State<LedDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _updateWaveAnimation();
  }

  @override
  void didUpdateWidget(LedDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateWaveAnimation();
  }

  void _updateWaveAnimation() {
    if (widget.isTransmitting || widget.isReceiving) {
      if (!_waveController.isAnimating) {
        _waveController.repeat();
      }
    } else {
      _waveController.stop();
      _waveController.value = 0;
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isTransmitting || widget.isReceiving;

    return Container(
      decoration: BoxDecoration(
        gradient: WalkieTheme.lcdGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: WalkieTheme.lcdShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: WalkieTheme.accent.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              // 内部纹理
              Positioned.fill(
                child: CustomPaint(
                  painter: _LcdTexturePainter(),
                ),
              ),
              // 内容
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 顶部：在线人数 + 设备ID + 信号
                    _buildTopBar(),
                    const Spacer(),
                    // 中间：讲话者大文字
                    _buildSpeakerSection(isActive),
                    const Spacer(),
                    // 底部：状态子文字
                    _buildStatusBar(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 在线人数
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.people_rounded,
              size: 18,
              color: WalkieTheme.lcdText,
            ),
            const SizedBox(width: 6),
            Text(
              '${widget.onlineCount + 1}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: WalkieTheme.lcdText,
              ),
            ),
          ],
        ),
        // 设备名/ID
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: WalkieTheme.lcdText.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            widget.deviceName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: WalkieTheme.lcdText,
              letterSpacing: 1,
            ),
          ),
        ),
        // 信号/连接状态
        _buildSignalIndicator(),
      ],
    );
  }

  Widget _buildSignalIndicator() {
    if (!widget.isConnected) {
      return Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: WalkieTheme.lcdTextDim,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(4, (i) {
            final active = widget.isTransmitting || widget.isReceiving;
            final wave = active
                ? (math.sin((_waveController.value * 2 * math.pi) +
                            i * 0.8) +
                        1) /
                    2
                : 1.0;
            return Container(
              width: 4,
              height: 6 + i * 4.0,
              margin: const EdgeInsets.only(left: 2),
              decoration: BoxDecoration(
                color: WalkieTheme.lcdText.withValues(
                  alpha: active ? 0.4 + wave * 0.6 : 1.0,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildSpeakerSection(bool isActive) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 声波动画圆环
        AnimatedBuilder(
          animation: _waveController,
          builder: (context, child) {
            return Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? WalkieTheme.lcdText.withValues(
                        alpha: 0.08 + (_waveController.value * 0.12))
                    : WalkieTheme.lcdText.withValues(alpha: 0.06),
                border: Border.all(
                  color: isActive
                      ? WalkieTheme.lcdText.withValues(
                          alpha: 0.3 + (_waveController.value * 0.4))
                      : WalkieTheme.lcdText.withValues(alpha: 0.15),
                  width: 2,
                ),
              ),
              child: Center(
                child: Icon(
                  isActive ? Icons.mic : Icons.mic_none,
                  size: 42,
                  color: WalkieTheme.lcdText.withValues(
                    alpha: isActive ? 0.9 : 0.5,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        // 讲话者文字
        Text(
          widget.speakerText,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: WalkieTheme.lcdText,
            letterSpacing: 1,
            height: 1.1,
            shadows: isActive
                ? [
                    BoxShadow(
                      color: WalkieTheme.lcdText.withValues(alpha: 0.3),
                      blurRadius: 12,
                    ),
                  ]
                : [],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isConnected
                ? WalkieTheme.lcdText
                : WalkieTheme.lcdTextDim,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          widget.statusSubtext.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: WalkieTheme.lcdText.withValues(alpha: 0.8),
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

/// LCD 屏幕纹理画笔
class _LcdTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 轻微扫描线
    final linePaint = Paint()
      ..color = WalkieTheme.lcdText.withValues(alpha: 0.03)
      ..strokeWidth = 1;

    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // 角落高光
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.8, -0.8),
        radius: 0.8,
        colors: [
          Colors.white.withValues(alpha: 0.12),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
