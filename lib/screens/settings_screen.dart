import 'package:flutter/material.dart';

import 'package:jiudhiduijiang/l10n/app_localizations.dart';
import 'package:jiudhiduijiang/theme/walkie_theme.dart';
import 'package:jiudhiduijiang/services/walkie_controller.dart';
import 'package:jiudhiduijiang/screens/about_screen.dart';

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
  bool _backgroundEnabled = true;
  bool _notificationEnabled = true;
  bool _audioConflictPause = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.controller.deviceName);
    _loadSplashPref();
    _loadPrefs();
  }

  Future<void> _loadSplashPref() async {
    final enabled = await WalkieController.loadSplashEnabled();
    if (mounted) setState(() => _splashEnabled = enabled);
  }

  Future<void> _loadPrefs() async {
    final bg = await WalkieController.loadBackgroundEnabled();
    final notif = await WalkieController.loadNotificationEnabled();
    final conflict = await WalkieController.loadAudioConflictPause();
    if (mounted) {
      setState(() {
        _backgroundEnabled = bg;
        _notificationEnabled = notif;
        _audioConflictPause = conflict;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: WalkieTheme.background,
      appBar: AppBar(
        title: Text(l.settings),
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
              _buildSectionHeader(l.device),
              _buildCard([
                _buildTextFieldRow(
                  icon: Icons.badge_outlined,
                  label: l.deviceName,
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
                  label: l.deviceId,
                  value: widget.controller.deviceId.substring(0, 8).toUpperCase(),
                ),
                _buildDivider(),
                _buildInfoRow(
                  icon: Icons.wifi,
                  label: l.localIp,
                  value: widget.controller.localIp,
                ),
              ]),
              const SizedBox(height: 24),

              _buildSectionHeader(l.audio),
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
                  label: l.mute,
                  value: widget.controller.isMuted,
                  onChanged: (val) => widget.controller.setMuted(val),
                ),
              ]),
              const SizedBox(height: 24),

              _buildSectionHeader(l.ui),
              _buildCard([
                _buildSwitchRow(
                  icon: Icons.image_outlined,
                  label: l.splashScreen,
                  value: _splashEnabled,
                  onChanged: (val) async {
                    await WalkieController.saveSplashEnabled(val);
                    setState(() => _splashEnabled = val);
                  },
                ),
              ]),
              const SizedBox(height: 24),

              _buildSectionHeader(l.notificationBackground),
              _buildCard([
                _buildSwitchRow(
                  icon: Icons.all_inclusive,
                  label: l.backgroundRunning,
                  value: _backgroundEnabled,
                  onChanged: (val) async {
                    await WalkieController.saveBackgroundEnabled(val);
                    setState(() => _backgroundEnabled = val);
                    if (val) {
                      widget.controller.startBackgroundService();
                    } else {
                      widget.controller.stopBackgroundService();
                    }
                  },
                ),
                _buildDivider(),
                _buildSwitchRow(
                  icon: Icons.notifications_active_outlined,
                  label: l.systemNotification,
                  value: _notificationEnabled,
                  onChanged: (val) async {
                    await WalkieController.saveNotificationEnabled(val);
                    setState(() => _notificationEnabled = val);
                  },
                ),
                _buildDivider(),
                _buildSwitchRow(
                  icon: Icons.phone_in_talk_outlined,
                  label: l.autoPauseOnCall,
                  value: _audioConflictPause,
                  onChanged: (val) async {
                    await WalkieController.saveAudioConflictPause(val);
                    setState(() => _audioConflictPause = val);
                    widget.controller.setAudioConflictPause(val);
                  },
                ),
              ]),
              const SizedBox(height: 24),

              _buildSectionHeader(l.connection),
              _buildCard([
                _buildInfoRow(
                  icon: Icons.people_alt_outlined,
                  label: l.onlineDevices,
                  value: '${widget.controller.onlineCount} 台',
                ),
                _buildDivider(),
                _buildInfoRow(
                  icon: Icons.signal_cellular_alt,
                  label: l.averageSignal,
                  value: _qualityText(widget.controller.averageSignalQuality, l),
                ),
              ]),
              const SizedBox(height: 24),

              _buildSectionHeader(l.messages),
              _buildCard([
                _buildInfoRow(
                  icon: Icons.chat_bubble_outline,
                  label: l.messageCount,
                  value: '${widget.controller.messageCount} 条',
                ),
                _buildDivider(),
                _buildActionRow(
                  icon: Icons.delete_outline,
                  label: l.clearMessages,
                  onTap: () {
                    widget.controller.clearMessages();
                    Navigator.pop(context);
                  },
                ),
              ]),
              const SizedBox(height: 24),

              _buildSectionHeader(l.about),
              _buildCard([
                _buildActionRow(
                  icon: Icons.info_outline,
                  label: l.aboutApp,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AboutScreen(),
                      ),
                    );
                  },
                  iconColor: WalkieTheme.accent,
                  textColor: WalkieTheme.textPrimary,
                  trailing: true,
                ),
                _buildDivider(),
                _buildInfoRow(
                  icon: Icons.tag,
                  label: l.version,
                  value: '1.0.0',
                ),
                _buildDivider(),
                _buildInfoRow(
                  icon: Icons.person_outline,
                  label: l.author,
                  value: '小聂',
                ),
              ]),
              const SizedBox(height: 32),
              Center(
                child: Text(
                  l.lanWalkie,
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

  String _qualityText(int q, AppLocalizations l) {
    switch (q) {
      case 4: return l.signalExcellent;
      case 3: return l.signalGood;
      case 2: return l.signalFair;
      case 1: return l.signalPoor;
      default: return l.signalNone;
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
    Color iconColor = WalkieTheme.txRed,
    Color textColor = WalkieTheme.txRed,
    bool trailing = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 15, color: textColor),
              ),
            ),
            if (trailing)
              const Icon(Icons.chevron_right, size: 20, color: WalkieTheme.textMuted),
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
