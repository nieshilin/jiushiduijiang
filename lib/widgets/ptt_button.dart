import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jiudhiduijiang/theme/walkie_theme.dart';

/// 现代大圆 PTT 按钮 — 底部按住说话
class PttButton extends StatefulWidget {
  final bool isPressed;
  final bool isTransmitting;
  final Function(bool) onPTTChanged;

  const PttButton({
    super.key,
    required this.isPressed,
    required this.isTransmitting,
    required this.onPTTChanged,
  });

  @override
  State<PttButton> createState() => _PttButtonState();
}

class _PttButtonState extends State<PttButton>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(PttButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTransmitting && !oldWidget.isTransmitting) {
      _glowController.repeat(reverse: true);
    } else if (!widget.isTransmitting && oldWidget.isTransmitting) {
      _glowController.animateTo(0);
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  void _onPanDown(DragDownDetails details) {
    _pressController.forward();
    HapticFeedback.mediumImpact();
    widget.onPTTChanged(true);
  }

  void _onPanUp(DragEndDetails details) {
    _pressController.reverse();
    widget.onPTTChanged(false);
  }

  void _onPanCancel() {
    _pressController.reverse();
    widget.onPTTChanged(false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanDown: _onPanDown,
      onPanEnd: _onPanUp,
      onPanCancel: _onPanCancel,
      child: AnimatedBuilder(
        animation: Listenable.merge([_glowController, _pressController]),
        builder: (context, child) {
          final glowValue = widget.isTransmitting ? _glowController.value : 0.0;
          final scale = _scaleAnimation.value;
          final buttonSize = 170.0 * scale;

          return Stack(
            alignment: Alignment.center,
            children: [
              // 外圈光晕
              if (widget.isTransmitting)
                Container(
                  width: buttonSize + 50,
                  height: buttonSize + 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: WalkieTheme.accentGlow.withValues(
                      alpha: 0.12 + glowValue * 0.18,
                    ),
                  ),
                ),
              // 外圈绿色环
              Container(
                width: buttonSize + 12,
                height: buttonSize + 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const SweepGradient(
                    colors: [
                      WalkieTheme.accent,
                      WalkieTheme.accentDim,
                      WalkieTheme.accent,
                    ],
                  ),
                  boxShadow: WalkieTheme.pttGlow(widget.isTransmitting),
                ),
              ),
              // 内圈主体
              Container(
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: WalkieTheme.pttGradient,
                  border: Border.all(
                    color: widget.isTransmitting
                        ? WalkieTheme.accent.withValues(alpha: 0.5)
                        : WalkieTheme.border,
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 点阵背景
                      CustomPaint(
                        size: Size(buttonSize, buttonSize),
                        painter: _DotMatrixPainter(
                          dotColor: widget.isTransmitting
                              ? WalkieTheme.accent.withValues(alpha: 0.25)
                              : WalkieTheme.textMuted.withValues(alpha: 0.3),
                          active: widget.isTransmitting,
                          progress: glowValue,
                        ),
                      ),
                      // 中心文字和图标
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            widget.isTransmitting
                                ? Icons.mic
                                : Icons.mic_none,
                            size: 44,
                            color: widget.isTransmitting
                                ? WalkieTheme.accent
                                : WalkieTheme.textSecondary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.isTransmitting ? '松手 发送' : '按住说话',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: widget.isTransmitting
                                  ? WalkieTheme.accent
                                  : WalkieTheme.textPrimary,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 点阵背景画笔
class _DotMatrixPainter extends CustomPainter {
  final Color dotColor;
  final bool active;
  final double progress;

  _DotMatrixPainter({
    required this.dotColor,
    required this.active,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const ringCount = 5;
    const dotsPerRing = 24;

    for (int ring = 0; ring < ringCount; ring++) {
      final r = radius * 0.25 + ring * radius * 0.12;
      final ringAlpha = 1.0 - ring * 0.12;
      final ringPaint = Paint()
        ..color = dotColor.withValues(alpha: dotColor.a * ringAlpha)
        ..style = PaintingStyle.fill;

      for (int i = 0; i < dotsPerRing; i++) {
        final angle = (i / dotsPerRing) * 2 * math.pi;
        // 讲话时让点阵旋转
        final rotation = active ? progress * 2 * math.pi * 0.3 : 0.0;
        final x = center.dx + r * math.cos(angle + rotation);
        final y = center.dy + r * math.sin(angle + rotation);

        // 只画在圆内
        if ((Offset(x, y) - center).distance < radius - 4) {
          canvas.drawCircle(
            Offset(x, y),
            2.0 + (active ? progress * 1.5 : 0),
            ringPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotMatrixPainter oldDelegate) {
    return oldDelegate.active != active || oldDelegate.progress != progress;
  }
}
