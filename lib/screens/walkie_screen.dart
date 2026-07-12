import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:jiudhiduijiang/theme/walkie_theme.dart';
import 'package:jiudhiduijiang/services/walkie_controller.dart';
import 'package:jiudhiduijiang/widgets/led_display.dart';
import 'package:jiudhiduijiang/widgets/status_indicator.dart';
import 'package:jiudhiduijiang/widgets/volume_control.dart';
import 'package:jiudhiduijiang/widgets/ptt_button.dart';
import 'package:jiudhiduijiang/widgets/device_list.dart';

/// 对讲机主界面 — 单一页面，无导航栏
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
    // 保持屏幕常亮
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

  /// 获取状态文本
  String _getStatusText(WalkieController c) {
    switch (c.talkStatus) {
      case TalkStatus.idle:
        return 'STANDBY';
      case TalkStatus.transmitting:
        return '>> TX LIVE';
      case TalkStatus.receiving:
        return '<< RX: ${c.receivingFrom}';
    }
  }

  /// 获取连接文本
  String _getConnectionText(WalkieController c) {
    switch (c.connStatus) {
      case ConnectionStatus.disconnected:
        return 'OFFLINE';
      case ConnectionStatus.connecting:
        return 'CONNECTING...';
      case ConnectionStatus.connected:
        return 'CONNECTED';
    }
  }

  /// 显示设备名称编辑对话框
  void _showNameEditor(BuildContext context, WalkieController c) {
    final controller = TextEditingController(text: c.deviceName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WalkieTheme.surfaceDark,
        title: Text(
          '设置设备名称',
          style: TextStyle(
            color: WalkieTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          style: TextStyle(color: WalkieTheme.textPrimary),
          decoration: InputDecoration(
            hintText: '输入设备名称',
            hintStyle: TextStyle(color: WalkieTheme.textDim),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: WalkieTheme.border),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: WalkieTheme.ledGreen),
            ),
            counterStyle: TextStyle(color: WalkieTheme.textDim),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: WalkieTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                c.setDeviceName(name);
              }
              Navigator.pop(ctx);
            },
            child: Text('确定', style: TextStyle(color: WalkieTheme.ledGreen)),
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

            // 初始化错误
            if (_initError != null) {
              return _buildErrorView();
            }

            // 初始化中
            if (!_isInitialized) {
              return _buildLoadingView();
            }

            return _buildWalkieBody(c);
          },
        ),
      ),
    );
  }

  /// 构建对讲机机身
  Widget _buildWalkieBody(WalkieController c) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            WalkieTheme.surfaceDark,
            WalkieTheme.background,
          ],
        ),
      ),
      child: Column(
        children: [
          // 顶部天线装饰
          _buildAntenna(),
          // 顶部工具栏（设备名编辑）
          _buildTopBar(c),
          // LED 显示屏
          LedDisplay(
            deviceId: c.deviceId,
            deviceName: c.deviceName,
            localIp: c.localIp,
            onlineCount: c.onlineCount,
            statusText: _getStatusText(c),
            connectionText: _getConnectionText(c),
            volume: c.volume,
            isMuted: c.isMuted,
          ),
          // 状态指示灯
          StatusIndicator(
            isTransmitting: c.talkStatus == TalkStatus.transmitting,
            isReceiving: c.talkStatus == TalkStatus.receiving,
            isConnected: c.connStatus == ConnectionStatus.connected,
          ),
          const SizedBox(height: 4),
          // 音量控制
          VolumeControl(
            volume: c.volume,
            isMuted: c.isMuted,
            onVolumeChanged: c.setVolume,
            onMuteToggle: c.toggleMute,
          ),
          const SizedBox(height: 8),
          // 设备列表
          DeviceList(devices: c.devices),
          const SizedBox(height: 8),
          // 接收提示
          if (c.talkStatus == TalkStatus.receiving)
            _buildReceivingIndicator(c.receivingFrom),
          // 弹性间距
          const Spacer(),
          // PTT 按钮
          PttButton(
            isPressed: c.isPTTActive,
            isTransmitting: c.talkStatus == TalkStatus.transmitting,
            label: 'PTT',
            onPTTChanged: (pressed) {
              if (pressed) {
                c.ptDown();
              } else {
                c.ptUp();
              }
            },
          ),
          const SizedBox(height: 24),
          // 底部日志
          if (c.lastLog.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                c.lastLog,
                style: TextStyle(
                  fontFamily: WalkieTheme.fontMono,
                  fontSize: 9,
                  color: WalkieTheme.textDim,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 天线装饰
  Widget _buildAntenna() {
    return Container(
      width: 6,
      height: 28,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: WalkieTheme.surfaceLight,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: WalkieTheme.border, width: 1),
      ),
    );
  }

  /// 顶部工具栏
  Widget _buildTopBar(WalkieController c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '就是对讲',
            style: TextStyle(
              fontFamily: WalkieTheme.fontMono,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: WalkieTheme.textDim,
              letterSpacing: 2,
            ),
          ),
          GestureDetector(
            onTap: () => _showNameEditor(context, c),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: WalkieTheme.surfaceMid,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: WalkieTheme.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, size: 12, color: WalkieTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '改名',
                    style: TextStyle(
                      fontSize: 11,
                      color: WalkieTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 接收中指示器
  Widget _buildReceivingIndicator(String fromName) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: WalkieTheme.ledGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: WalkieTheme.ledGreen.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.graphic_eq, size: 16, color: WalkieTheme.ledGreen),
          const SizedBox(width: 8),
          Text(
            '收到 $fromName 的语音',
            style: TextStyle(
              fontFamily: WalkieTheme.fontMono,
              fontSize: 11,
              color: WalkieTheme.ledGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// 加载视图
  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: WalkieTheme.ledGreen,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '正在连接局域网...',
            style: TextStyle(
              fontFamily: WalkieTheme.fontMono,
              fontSize: 12,
              color: WalkieTheme.textSecondary,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  /// 错误视图
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: WalkieTheme.ledRed),
            const SizedBox(height: 16),
            Text(
              '初始化失败',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: WalkieTheme.ledRed,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _initError ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
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
                backgroundColor: WalkieTheme.surfaceLight,
                foregroundColor: WalkieTheme.ledGreen,
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
