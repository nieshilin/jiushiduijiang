import 'package:flutter/material.dart';

import 'package:jiudhiduijiang/theme/walkie_theme.dart';
import 'package:jiudhiduijiang/services/walkie_controller.dart';

/// 设置页面 — 设备名、音量、静音、关于
class SettingsScreen extends StatefulWidget {
  final WalkieController controller;

  const SettingsScreen({super.key, required this.controller});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameController;
  bool _splashEnabled = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.controller.deviceName);
    _loadSplashPref();
  }

  Future<void> _loadSplashPref() async {
    final enabled = await WalkieController.loadSplashEnabled();
    if (mounted) setState(() => _splashEnabled = enabled);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WalkieTheme.background,
      appBar: AppBar(
        title: const Text('设置'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildSectionHeader('设备'),
              _buildCard([
                _buildTextFieldRow(
                  icon: Icons.badge_outlined,
                  label: '设备名称',
                  controller: _nameController,
                  onSave: (val) {
                    if (val.isNotEmpty) {
                      widget.controller.setDeviceName(val);
                    }
                  },
                ),
                _buildDivider(),
                _buildInfoRow(
                  icon: Icons.fingerprint,
                  label: '设备 ID',
                  value: widget.controller.deviceId.substring(0, 8).toUpperCase(),
                ),
                _buildDivider(),
                _buildInfoRow(
                  icon: Icons.wifi,
                  label: '本机 IP',
                  value: widget.controller.localIp,
                ),
              ]),
              const SizedBox(height: 24),

              _buildSectionHeader('音频'),
              _buildCard([
                // 音量滑块
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.volume_down, size: 20, color: WalkieTheme.textSecondary),
                      Expanded(
                        child: Slider(
                          value: widget.controller.volume,
                          min: 0.0,
                          max: 1.0,
                          divisions: 20,
                          activeColor: WalkieTheme.accent,
                          inactiveColor: WalkieTheme.border,
                          thumbColor: WalkieTheme.accent,
                          onChanged: widget.controller.isMuted
                              ? null
                              : (val) => widget.controller.setVolume(val),
                        ),
                      ),
                      const Icon(Icons.volume_up, size: 20, color: WalkieTheme.textSecondary),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${(widget.controller.volume * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 13,
                            color: WalkieTheme.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildDivider(),
                // 静音开关
                _buildSwitchRow(
                  icon: widget.controller.isMuted
                      ? Icons.volume_off
                      : Icons.volume_up,
                  label: '静音',
                  value: widget.controller.isMuted,
                  onChanged: (val) => widget.controller.setMuted(val),
                ),
              ]),
              const SizedBox(height: 24),

              _buildSectionHeader('界面'),
              _buildCard([
                _buildSwitchRow(
                  icon: Icons.image_outlined,
                  label: '启动页',
                  value: _splashEnabled,
                  onChanged: (val) async {
                    await WalkieController.saveSplashEnabled(val);
                    setState(() => _splashEnabled = val);
                  },
                ),
              ]),
              const SizedBox(height: 24),

              _buildSectionHeader('连接'),
              _buildCard([
                _buildInfoRow(
                  icon: Icons.people_alt_outlined,
                  label: '在线设备',
                  value: '${widget.controller.onlineCount} 台',
                ),
                _buildDivider(),
                _buildInfoRow(
                  icon: Icons.signal_cellular_alt,
                  label: '平均信号',
                  value: _qualityText(widget.controller.averageSignalQuality),
                ),
              ]),
              const SizedBox(height: 24),

              _buildSectionHeader('消息'),
              _buildCard([
                _buildInfoRow(
                  icon: Icons.chat_bubble_outline,
                  label: '消息总数',
                  value: '${widget.controller.messageCount} 条',
                ),
                _buildDivider(),
                _buildActionRow(
                  icon: Icons.delete_outline,
                  label: '清空消息记录',
                  onTap: () {
                    widget.controller.clearMessages();
                    Navigator.pop(context);
                  },
                ),
              ]),
              const SizedBox(height: 24),

              _buildSectionHeader('关于'),
              _buildCard([
                _buildInfoRow(
                  icon: Icons.info_outline,
                  label: '应用名称',
                  value: '就是对讲',
                ),
                _buildDivider(),
                _buildInfoRow(
                  icon: Icons.tag,
                  label: '版本',
                  value: '1.0.0',
                ),
                _buildDivider(),
                _buildInfoRow(
                  icon: Icons.lan,
                  label: '协议',
                  value: 'UDP 广播',
                ),
              ]),
              const SizedBox(height: 32),
              Center(
                child: Text(
                  '就是一个局域网对讲机',
                  style: TextStyle(
                    fontSize: 12,
                    color: WalkieTheme.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }

  String _qualityText(int q) {
    switch (q) {
      case 4: return '极好';
      case 3: return '良好';
      case 2: return '一般';
      case 1: return '较差';
      default: return '无信号';
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: WalkieTheme.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: WalkieTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WalkieTheme.border),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 56, endIndent: 16, color: WalkieTheme.divider);
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: WalkieTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 15, color: WalkieTheme.textPrimary),
            ),
          ),
          Text(
            value,
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

  Widget _buildActionRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: WalkieTheme.txRed),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 15, color: WalkieTheme.txRed),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: WalkieTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 15, color: WalkieTheme.textPrimary),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: WalkieTheme.accent,
            inactiveThumbColor: WalkieTheme.textMuted,
            inactiveTrackColor: WalkieTheme.border,
          ),
        ],
      ),
    );
  }

  Widget _buildTextFieldRow({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required Function(String) onSave,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: WalkieTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              maxLength: 20,
              style: const TextStyle(
                fontSize: 15,
                color: WalkieTheme.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: label,
                hintStyle: const TextStyle(color: WalkieTheme.textMuted),
                counterText: '',
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: WalkieTheme.border),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: WalkieTheme.accent),
                ),
              ),
              onSubmitted: onSave,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle, color: WalkieTheme.accent, size: 22),
            onPressed: () => onSave(controller.text.trim()),
          ),
        ],
      ),
    );
  }
}
