import 'package:flutter/material.dart';
import 'package:jiudhiduijiang/theme/walkie_theme.dart';

/// 状态指示灯组 — 通话中闪烁/待机常亮动画
class StatusIndicator extends StatefulWidget {
  final bool isTransmitting;
  final bool isReceiving;
  final bool isConnected;

  const StatusIndicator({
    super.key,
    required this.isTransmitting,
    required this.isReceiving,
    required this.isConnected,
  });

  @override
  State<StatusIndicator> createState() => _StatusIndicatorState();
}

class _StatusIndicatorState extends State<StatusIndicator>
    with TickerProviderStateMixin {
  late AnimationController _transmitController;
  late AnimationController _receiveController;
  late AnimationController _idleController;

  @override
  void initState() {
    super.initState();
    _transmitController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _receiveController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _idleController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(StatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTransmitting) {
      _transmitController.repeat(reverse: true);
    } else {
      _transmitController.stop();
    }
    if (widget.isReceiving) {
      _receiveController.repeat(reverse: true);
    } else {
      _receiveController.stop();
    }
  }

  @override
  void dispose() {
    _transmitController.dispose();
    _receiveController.dispose();
    _idleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 发送指示灯（红）
          _buildLed(
            label: 'TX',
            activeColor: WalkieTheme.ledRed,
            isActive: widget.isTransmitting,
            controller: _transmitController,
            idleColor: WalkieTheme.ledDim,
          ),
          // 接收指示灯（绿）
          _buildLed(
            label: 'RX',
            activeColor: WalkieTheme.ledGreen,
            isActive: widget.isReceiving,
            controller: _receiveController,
            idleColor: WalkieTheme.ledDim,
          ),
          // 连接指示灯（蓝）— 待机常亮呼吸
          _buildConnectionLed(),
        ],
      ),
    );
  }

  Widget _buildLed({
    required String label,
    required Color activeColor,
    required bool isActive,
    required AnimationController controller,
    required Color idleColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            final brightness = isActive ? controller.value : 0.0;
            return Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? activeColor.withValues(alpha: 0.3 + brightness * 0.7)
                    : idleColor,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.4 + brightness * 0.6),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: WalkieTheme.fontMono,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: WalkieTheme.textSecondary,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionLed() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _idleController,
          builder: (context, child) {
            final baseAlpha = widget.isConnected ? 0.5 : 0.15;
            final breath = widget.isConnected
                ? baseAlpha + _idleController.value * 0.5
                : baseAlpha;
            return Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: WalkieTheme.ledBlue.withValues(alpha: breath),
                boxShadow: widget.isConnected
                    ? [
                        BoxShadow(
                          color: WalkieTheme.ledBlue
                              .withValues(alpha: breath * 0.6),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Text(
          'NET',
          style: TextStyle(
            fontFamily: WalkieTheme.fontMono,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: WalkieTheme.textSecondary,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
