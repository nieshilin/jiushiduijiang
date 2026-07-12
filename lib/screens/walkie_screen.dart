import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:jiudhiduijiang/l10n/app_localizations.dart';
import 'package:jiudhiduijiang/theme/walkie_theme.dart';
import 'package:jiudhiduijiang/services/walkie_controller.dart';
import 'package:jiudhiduijiang/screens/settings_screen.dart';
import 'package:jiudhiduijiang/screens/message_panel.dart';
import 'package:jiudhiduijiang/widgets/led_display.dart';
import 'package:jiudhiduijiang/widgets/ptt_button.dart';
import 'package:jiudhiduijiang/widgets/device_list.dart';
import 'package:permission_handler/permission_handler.dart';

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
    // 从设置页返回后若权限仍被拒绝，重新弹出引导弹窗
    widget.controller.onPermissionRecheck = () {
      if (mounted) _showPermissionDialog();
    };
    _init();
    WakelockPlus.enable();
  }

  Future<void> _init() async {
    try {
      await widget.controller.init();
      setState(() => _isInitialized = true);
      // 检查权限是否被拒绝
      if (widget.controller.micPermissionDenied) {
        _showPermissionDialog();
      }
    } catch (e) {
      setState(() => _initError = e.toString());
    }
  }

  /// 权限被拒绝时显示引导弹窗
  void _showPermissionDialog() {
    final l = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: WalkieTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: WalkieTheme.border),
        ),
        title: Row(
          children: [
            const Icon(Icons.mic_off, color: WalkieTheme.txRed, size: 24),
            const SizedBox(width: 8),
            Text(
              l.micPermissionDenied,
              style: const TextStyle(
                color: WalkieTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          l.micPermissionGuide,
          style: const TextStyle(color: WalkieTheme.textSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.later,
                style: const TextStyle(color: WalkieTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: Text(l.goToSettings,
                style: const TextStyle(color: WalkieTheme.accent)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    widget.controller.onPermissionRecheck = null;
    WakelockPlus.disable();
    super.dispose();
  }

  String _getSpeakerText(WalkieController c) {
    final l = AppLocalizations.of(context)!;
    switch (c.talkStatus) {
      case TalkStatus.transmitting:
        return l.youSpeaking;
      case TalkStatus.receiving:
        return l.peerSpeaking(c.receivingFrom);
      case TalkStatus.idle:
        return l.standby;
    }
  }

  String _getStatusSubtext(WalkieController c) {
    final l = AppLocalizations.of(context)!;
    switch (c.talkStatus) {
      case TalkStatus.transmitting:
        return l.releaseToEnd;
      case TalkStatus.receiving:
        return l.receivingVoice;
      case TalkStatus.idle:
        final base = c.connStatus == ConnectionStatus.connected
            ? l.onlineCount(c.onlineCount)
            : l.connecting;
        // 附加 WebRTC ICE 媒体连接状态
        if (c.webrtcConnectedCount > 0) {
          return '$base  |  ICE: ${c.webrtcConnectedCount}';
        }
        return base;
    }
  }

  void _showNameEditor(BuildContext context, WalkieController c) {
    final l = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: c.deviceName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WalkieTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: WalkieTheme.border),
        ),
        title: Text(
          l.setDeviceName,
          style: const TextStyle(
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
          decoration: InputDecoration(
            hintText: l.enterDeviceName,
            hintStyle: const TextStyle(color: WalkieTheme.textMuted),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: WalkieTheme.border),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: WalkieTheme.accent),
            ),
            counterStyle: const TextStyle(color: WalkieTheme.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel,
                style: const TextStyle(color: WalkieTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                c.setDeviceName(name);
              }
              Navigator.pop(ctx);
            },
            child: Text(l.confirm,
                style: const TextStyle(color: WalkieTheme.accent)),
          ),
        ],
      ),
    );
  }

  void _openSettings(WalkieController c) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(controller: c),
      ),
    );
  }

  void _openMessages(WalkieController c) {
    c.markMessagesRead();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MessagePanel(
        messages: c.messages,
        localDeviceName: c.deviceName,
        onSend: (text) => c.sendMessage(text),
      ),
    );
  }

  void _showVolumePopup(WalkieController c) {
    final l = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: WalkieTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: WalkieTheme.border),
        ),
        title: Row(
          children: [
            Icon(
              c.isMuted ? Icons.volume_off : Icons.volume_up,
              color: WalkieTheme.accent,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              l.volumeControl,
              style: const TextStyle(
                color: WalkieTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: AnimatedBuilder(
          animation: c,
          builder: (context, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 音量滑块
                Row(
                  children: [
                    const Icon(Icons.volume_down,
                        size: 20, color: WalkieTheme.textSecondary),
                    Expanded(
                      child: Slider(
                        value: c.volume,
                        min: 0.0,
                        max: 1.0,
                        divisions: 20,
                        activeColor: WalkieTheme.accent,
                        inactiveColor: WalkieTheme.border,
                        thumbColor: WalkieTheme.accent,
                        onChanged: c.isMuted
                            ? null
                            : (val) => c.setVolume(val),
                      ),
                    ),
                    const Icon(Icons.volume_up,
                        size: 20, color: WalkieTheme.textSecondary),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${(c.volume * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 14,
                    color: WalkieTheme.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                // 静音开关
                ListTile(
                  leading: Icon(
                    c.isMuted ? Icons.volume_off : Icons.volume_up,
                    color: c.isMuted ? WalkieTheme.txRed : WalkieTheme.textSecondary,
                    size: 22,
                  ),
                  title: Text(
                    l.mute,
                    style: TextStyle(
                      fontSize: 15,
                      color: c.isMuted ? WalkieTheme.txRed : WalkieTheme.textPrimary,
                    ),
                  ),
                  trailing: Switch(
                    value: c.isMuted,
                    onChanged: (val) => c.setMuted(val),
                    activeColor: WalkieTheme.accent,
                    inactiveThumbColor: WalkieTheme.textMuted,
                    inactiveTrackColor: WalkieTheme.border,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.close,
                style: const TextStyle(color: WalkieTheme.accent)),
          ),
        ],
      ),
    );
  }

  /// 退出确认弹窗
  Future<bool> _showExitConfirm() async {
    final l = AppLocalizations.of(context)!;
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WalkieTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: WalkieTheme.border),
        ),
        title: Text(
          l.exitApp,
          style: const TextStyle(
            color: WalkieTheme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          l.exitConfirm,
          style: const TextStyle(color: WalkieTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel,
                style: const TextStyle(color: WalkieTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.exit,
                style: const TextStyle(color: WalkieTheme.txRed)),
          ),
        ],
      ),
    ) ?? false;
  }

  /// 清理并退出
  void _cleanupAndExit() {
    // 停止录音（如果正在进行）
    if (widget.controller.talkStatus == TalkStatus.transmitting) {
      widget.controller.ptUp();
    }
    // 停止播放
    // 控制器的 dispose 会处理服务停止和资源释放
    // 发送 leave 通知由 discovery_service.stop() 处理
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _showExitConfirm();
        if (shouldExit && context.mounted) {
          _cleanupAndExit();
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
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
      ),
    );
  }

  Widget _buildMainBody(WalkieController c) {
    return Column(
      children: [
        // 顶部状态栏 + 功能按钮
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
              signalQuality: c.averageSignalQuality,
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
        // 功能按钮行 + 大圆 PTT 按钮
        _buildActionRow(c),
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
          // 设置按钮
          GestureDetector(
            onTap: () => _openSettings(c),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: WalkieTheme.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(color: WalkieTheme.border),
              ),
              child: const Icon(Icons.settings,
                  size: 20, color: WalkieTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(WalkieController c) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 音量快捷按钮
          _buildActionButton(
            icon: c.isMuted ? Icons.volume_off : Icons.volume_up,
            label: c.isMuted ? l.muted : l.volume,
            color: c.isMuted ? WalkieTheme.txRed : WalkieTheme.textSecondary,
            onTap: () => _showVolumePopup(c),
          ),
          // PTT 按钮
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
          // 消息按钮
          _buildActionButton(
            icon: Icons.chat_bubble_outline,
            label: l.messages,
            color: WalkieTheme.textSecondary,
            badge: c.unreadCount,
            onTap: () => _openMessages(c),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    int badge = 0,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: WalkieTheme.surfaceElevated,
                  shape: BoxShape.circle,
                  border: Border.all(color: WalkieTheme.border),
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              if (badge > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: WalkieTheme.txRed,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: WalkieTheme.accent,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l.connecting,
            style: const TextStyle(
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
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: WalkieTheme.txRed),
            const SizedBox(height: 16),
            Text(
              l.initFailed,
              style: const TextStyle(
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
              child: Text(l.retry),
            ),
          ],
        ),
      ),
    );
  }
}
