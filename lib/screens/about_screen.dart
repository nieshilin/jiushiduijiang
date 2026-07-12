import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:jiudhiduijiang/theme/walkie_theme.dart';
import 'package:jiudhiduijiang/utils/constants.dart';

/// 关于本应用 — 显示版本号、作者信息、技术栈等
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label 已复制'),
        duration: const Duration(seconds: 1),
        backgroundColor: WalkieTheme.surface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WalkieTheme.background,
      appBar: AppBar(
        title: const Text('关于本应用'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── App 图标 + 名称 + 版本 ──
          _buildAppHeader(),
          const SizedBox(height: 28),

          // ── 版本信息 ──
          _buildSectionHeader('版本信息'),
          _buildCard([
            _buildInfoRow(
              icon: Icons.info_outline,
              label: '应用名称',
              value: AppConstants.appName,
            ),
            _buildDivider(),
            _buildInfoRow(
              icon: Icons.tag,
              label: '版本号',
              value: '${AppConstants.appVersion} (${AppConstants.appBuildNumber})',
            ),
            _buildDivider(),
            _buildInfoRow(
              icon: Icons.code,
              label: '构建',
              value: 'Flutter ${_flutterVersion()}',
            ),
          ]),
          const SizedBox(height: 24),

          // ── 作者信息 ──
          _buildSectionHeader('作者信息'),
          _buildCard([
            _buildInfoRow(
              icon: Icons.person_outline,
              label: '作者',
              value: AppConstants.authorName,
            ),
            _buildDivider(),
            _buildTapRow(
              icon: Icons.email_outlined,
              label: '邮箱',
              value: AppConstants.authorEmail,
              onTap: () => _copyToClipboard(context, AppConstants.authorEmail, '邮箱'),
            ),
            _buildDivider(),
            _buildTapRow(
              icon: Icons.language,
              label: '个人博客',
              value: AppConstants.authorBlog,
              onTap: () => _launchUrl('https://${AppConstants.authorBlog}'),
            ),
            _buildDivider(),
            _buildTapRow(
              icon: Icons.code,
              label: 'GitHub',
              value: 'jiushiduijiang',
              onTap: () => _launchUrl(AppConstants.githubRepo),
            ),
          ]),
          const SizedBox(height: 24),

          // ── 技术栈 ──
          _buildSectionHeader('技术栈'),
          _buildCard([
            _buildTechRow('Flutter', '跨平台 UI 框架'),
            _buildDivider(),
            _buildTechRow('Dart', '开发语言'),
            _buildDivider(),
            _buildTechRow('UDP 广播', '设备发现与语音传输'),
            _buildDivider(),
            _buildTechRow('record', '音频录制 (PCM16)'),
            _buildDivider(),
            _buildTechRow('audioplayers', '音频播放'),
            _buildDivider(),
            _buildTechRow('shared_preferences', '本地配置存储'),
          ]),
          const SizedBox(height: 24),

          // ── 功能特性 ──
          _buildSectionHeader('功能特性'),
          _buildCard(
            _buildFeatureList().map((f) {
              final index = _buildFeatureList().indexOf(f);
              return Column(
                children: [
                  if (index > 0) _buildDivider(),
                  _buildFeatureRow(f),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // ── 开源说明 ──
          _buildSectionHeader('开源说明'),
          _buildCard([
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '就是对讲',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: WalkieTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '一个基于局域网 UDP 广播的跨平台对讲机应用，支持 Android、iOS、Windows 平台。无需服务器，同一 WiFi 下即可使用。',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: WalkieTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '© 2026 ${AppConstants.authorName}. All rights reserved.',
                    style: TextStyle(
                      fontSize: 12,
                      color: WalkieTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _flutterVersion() => '3.32.4';

  // ── App 头部 ──

  Widget _buildAppHeader() {
    return Center(
      child: Column(
        children: [
          // App 图标
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: WalkieTheme.pttGradient,
              border: Border.all(color: WalkieTheme.accent.withValues(alpha: 0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: WalkieTheme.accent.withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/splash/splash.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, child) => Icon(
                  Icons.record_voice_over,
                  size: 44,
                  color: WalkieTheme.accent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppConstants.appName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: WalkieTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: WalkieTheme.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: WalkieTheme.accent.withValues(alpha: 0.3)),
            ),
            child: Text(
              'v${AppConstants.appVersion}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: WalkieTheme.accent,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '局域网跨平台对讲机',
            style: TextStyle(
              fontSize: 13,
              color: WalkieTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── 功能列表 ──

  List<String> _buildFeatureList() => [
    'UDP 设备自动发现与心跳保活',
    'PTT 按住说话，半双工语音对讲',
    '实时信号质量指示 (RTT 延迟)',
    '文字消息收发与消息面板',
    '音量调节与静音控制',
    '后台常驻运行与保活通知',
    '来电音频冲突自动暂停',
    '自定义 App 图标与启动页',
  ];

  // ── 构建组件 ──

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

  Widget _buildTapRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: WalkieTheme.accent),
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
                color: WalkieTheme.accent,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 18, color: WalkieTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildTechRow(String name, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.memory, size: 20, color: WalkieTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 15, color: WalkieTheme.textPrimary),
            ),
          ),
          Text(
            desc,
            style: TextStyle(fontSize: 13, color: WalkieTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(String feature) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 18, color: WalkieTheme.accent.withValues(alpha: 0.8)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              feature,
              style: const TextStyle(fontSize: 14, color: WalkieTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
