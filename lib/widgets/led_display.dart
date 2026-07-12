import 'package:flutter/material.dart';
import 'package:jiudhiduijiang/theme/walkie_theme.dart';

/// 顶部 LED 模拟显示屏
/// 显示本机ID、在线设备数、对讲状态、连接状态、音量
class LedDisplay extends StatelessWidget {
  final String deviceId;
  final String deviceName;
  final String localIp;
  final int onlineCount;
  final String statusText;
  final String connectionText;
  final double volume;
  final bool isMuted;

  const LedDisplay({
    super.key,
    required this.deviceId,
    required this.deviceName,
    required this.localIp,
    required this.onlineCount,
    required this.statusText,
    required this.connectionText,
    required this.volume,
    required this.isMuted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: WalkieTheme.ledScreenBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: WalkieTheme.border, width: 2),
        boxShadow: [
          BoxShadow(
            color: WalkieTheme.ledGreen.withValues(alpha: 0.05),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第一行: 设备名称 + IP
          _buildLine(
            deviceName,
            right: localIp.isEmpty ? '---' : localIp,
          ),
          const SizedBox(height: 6),
          // 第二行: 在线设备数 + 连接状态
          _buildLine(
            'ONLINE: ${onlineCount.toString().padLeft(2, '0')}',
            right: connectionText,
          ),
          const SizedBox(height: 6),
          // 第三行: 对讲状态 + 音量
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildText(statusText, bright: true),
              _buildText(
                isMuted
                    ? 'MUTE'
                    : 'VOL:${(volume * 100).round().toString().padLeft(3, '0')}%',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLine(String left, {String right = ''}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildText(left),
        if (right.isNotEmpty) _buildText(right),
      ],
    );
  }

  Widget _buildText(String text, {bool bright = false}) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: WalkieTheme.fontMono,
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: bright
            ? WalkieTheme.ledScreenText
            : WalkieTheme.ledScreenText.withValues(alpha: 0.8),
        letterSpacing: 1.5,
        height: 1.2,
      ),
    );
  }
}
