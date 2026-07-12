import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:jiudhiduijiang/theme/walkie_theme.dart';
import 'package:jiudhiduijiang/services/walkie_controller.dart';
import 'package:jiudhiduijiang/widgets/led_display.dart';
import 'package:jiudhiduijiang/widgets/ptt_button.dart';
import 'package:jiudhiduijiang/widgets/device_list.dart';

/// 对讲机主界面 — 现代极简移动端风格
class WalkieScreen extends StatefulWidget {
  final WalkieController controller;

  const WalkieScreen({super.key, required this.controller});

  @override
  State<WalkieScreen> createState() => _WalkieScreenState();
}

class _WalkieScreenState extends State<WalkieScreen> {
  bool _isInitialized = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _init();
    WakelockPlus.enable();
  }

  Future<void> _init() async {
    try {
      await widget.controller.init();
      setState(() => _isInitialized = true);
    } catch (e) {
      setState(() => _initError = e.toString());
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  String _getChannelName(WalkieController c) {
    return '默认频道';
  }

  String _getSpeakerText(WalkieController c) {
    switch (c.talkStatus) {
      case TalkStatus.transmitting:
        return '你正在讲话';
      case TalkStatus.receiving:
        return '${c.receivingFrom} 正在讲话';
      case TalkStatus.idle:
        return '频道空闲';
    }
  }

  String _getStatusSubtext(WalkieController c) {
    switch (c.talkStatus) {
      case TalkStatus.transmitting:
        return '松开按钮结束通话';
      case TalkStatus.receiving:
        return '接收语音中';
      case TalkStatus.idle:
        return c.connStatus == ConnectionStatus.connected
            ? '在线 · ${c.onlineCount} 人'
            : '连接中...';
    }
  }

  void _showNameEditor(BuildContext context, WalkieController c) {
    final controller = TextEditingController(text: c.deviceName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WalkieTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: WalkieTheme.border),
        ),
        title: const Text(
          '设置设备名称',
          style: TextStyle(
            color: WalkieTheme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          style: const TextStyle(color: WalkieTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: '输入设备名称',
            hintStyle: TextStyle(color: WalkieTheme.textMuted),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: WalkieTheme.border),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: WalkieTheme.accent),
            ),
            counterStyle: TextStyle(color: WalkieTheme.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消',
                style: TextStyle(color: WalkieTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                c.setDeviceName(name);
              }
              Navigator.pop(ctx);
            },
            child: const Text('确定',
                style: TextStyle(color: WalkieTheme.accent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WalkieTheme.background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final c = widget.controller;

            if (_initError != null) {
              return _buildErrorView();
            }

            if (!_isInitialized) {
              return _buildLoadingView();
            }

            return _buildMainBody(c);
          },
        ),
      ),
    );
  }

  Widget _buildMainBody(WalkieController c) {
    return Column(
      children: [
        // 顶部状态栏 + 频道选择
        _buildTopBar(c),
        const SizedBox(height: 24),
        // 绿色 LCD 大屏
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: LedDisplay(
              deviceId: c.deviceId,
              deviceName: c.deviceName,
              onlineCount: c.onlineCount,
              speakerText: _getSpeakerText(c),
              statusSubtext: _getStatusSubtext(c),
              isTransmitting: c.talkStatus == TalkStatus.transmitting,
              isReceiving: c.talkStatus == TalkStatus.receiving,
              isConnected: c.connStatus == ConnectionStatus.connected,
            ),
          ),
        ),
        const SizedBox(height: 20),
        // 在线成员列表
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: DeviceList(
              devices: c.devices,
              localDeviceName: c.deviceName,
              speakingName: c.talkStatus == TalkStatus.transmitting
                  ? c.deviceName
                  : c.receivingFrom,
            ),
          ),
        ),
        const SizedBox(height: 24),
        // 大圆 PTT 按钮
        PttButton(
          isPressed: c.isPTTActive,
          isTransmitting: c.talkStatus == TalkStatus.transmitting,
          onPTTChanged: (pressed) {
            if (pressed) {
              c.ptDown();
            } else {
              c.ptUp();
            }
          },
        ),
        const SizedBox(height: 36),
      ],
    );
  }

  Widget _buildTopBar(WalkieController c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 改名
          GestureDetector(
            onTap: () => _showNameEditor(context, c),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: WalkieTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: WalkieTheme.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.edit, size: 14, color: WalkieTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    c.deviceName,
                    style: const TextStyle(
                      fontSize: 13,
                      color: WalkieTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 频道选择器
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: WalkieTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: WalkieTheme.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_tethering,
                    size: 14, color: WalkieTheme.accent),
                const SizedBox(width: 6),
                Text(
                  _getChannelName(c),
                  style: const TextStyle(
                    fontSize: 13,
                    color: WalkieTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down,
                    size: 16, color: WalkieTheme.textSecondary),
              ],
            ),
          ),
          // 更多菜单（占位）
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: WalkieTheme.surfaceElevated,
              shape: BoxShape.circle,
              border: Border.all(color: WalkieTheme.border),
            ),
            child: const Icon(Icons.more_horiz,
                size: 20, color: WalkieTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: WalkieTheme.accent,
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 16),
          Text(
            '正在连接频道...',
            style: TextStyle(
              fontSize: 14,
              color: WalkieTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: WalkieTheme.txRed),
            const SizedBox(height: 16),
            const Text(
              '初始化失败',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: WalkieTheme.txRed,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _initError ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: WalkieTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _initError = null;
                  _isInitialized = false;
                });
                _init();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: WalkieTheme.surfaceElevated,
                foregroundColor: WalkieTheme.accent,
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
