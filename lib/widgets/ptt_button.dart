import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jiudhiduijiang/theme/walkie_theme.dart';

/// 大尺寸 PTT 按住说话按钮
/// 按下时有震动/灯光反馈动画
class PttButton extends StatefulWidget {
  final bool isPressed;
  final bool isTransmitting;
  final String label;
  final Function(bool) onPTTChanged;

  const PttButton({
    super.key,
    required this.isPressed,
    required this.isTransmitting,
    required this.label,
    required this.onPTTChanged,
  });

  @override
  State<PttButton> createState() => _PttButtonState();
}

class _PttButtonState extends State<PttButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 200),
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
          final buttonSize = 180.0 * scale;

          return Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: widget.isTransmitting
                    ? [
                        WalkieTheme.pttPressed,
                        WalkieTheme.pttPressed.withValues(alpha: 0.7),
                        WalkieTheme.pttIdle,
                      ]
                    : [
                        WalkieTheme.surfaceLight,
                        WalkieTheme.surfaceMid,
                        WalkieTheme.surfaceDark,
                      ],
              ),
              border: Border.all(
                color: widget.isTransmitting
                    ? WalkieTheme.pttPressed
                    : WalkieTheme.border,
                width: 3,
              ),
              boxShadow: [
                // 外发光
                if (widget.isTransmitting)
                  BoxShadow(
                    color: WalkieTheme.pttGlow
                        .withValues(alpha: 0.4 + glowValue * 0.4),
                    blurRadius: 30 + glowValue * 20,
                    spreadRadius: 4 + glowValue * 6,
                  ),
                // 内阴影
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.isTransmitting ? Icons.mic : Icons.mic_none,
                  size: 48,
                  color: widget.isTransmitting
                      ? Colors.white
                      : WalkieTheme.textSecondary,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isTransmitting ? '正在通话' : widget.label,
                  style: TextStyle(
                    fontFamily: WalkieTheme.fontMono,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: widget.isTransmitting
                        ? Colors.white
                        : WalkieTheme.textPrimary,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.isTransmitting ? 'PTT · LIVE' : '按住说话',
                  style: TextStyle(
                    fontFamily: WalkieTheme.fontMono,
                    fontSize: 10,
                    color: widget.isTransmitting
                        ? Colors.white.withValues(alpha: 0.7)
                        : WalkieTheme.textDim,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
