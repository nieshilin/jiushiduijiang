import 'package:flutter/material.dart';
import 'package:jiudhiduijiang/theme/walkie_theme.dart';
import 'package:jiudhiduijiang/models/device.dart';
import 'package:jiudhiduijiang/widgets/signal_indicator.dart';

/// 在线成员列表 — 现代极简风格 + 信号质量指示
class DeviceList extends StatelessWidget {
  final List<Device> devices;
  final String localDeviceName;
  final String speakingName;

  const DeviceList({
    super.key,
    required this.devices,
    required this.localDeviceName,
    required this.speakingName,
  });

  @override
  Widget build(BuildContext context) {
    // 组合本地设备和在线设备
    final localEntry = _MemberItem(
      name: localDeviceName,
      isLocal: true,
      isOnline: true,
      isSpeaking: speakingName == localDeviceName,
      signalQuality: 4, // 本机信号满格
    );

    final onlineDevices = devices.where((d) => d.isOnline).toList();
    final memberList = [
      localEntry,
      ...onlineDevices.map((d) => _MemberItem(
            name: d.name,
            isLocal: false,
            isOnline: d.isOnline,
            isSpeaking: speakingName == d.name,
            signalQuality: d.signalQuality,
          ))
    ];

    if (memberList.length <= 1 && onlineDevices.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: WalkieTheme.online,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '在线成员',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: WalkieTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${memberList.length}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: WalkieTheme.accent,
                ),
              ),
            ],
          ),
        ),
        // 成员列表
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: WalkieTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: WalkieTheme.border),
            ),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: memberList.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                indent: 56,
                endIndent: 16,
                color: WalkieTheme.divider,
              ),
              itemBuilder: (context, index) {
                return _buildMemberItem(memberList[index]);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            '在线成员',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: WalkieTheme.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: WalkieTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: WalkieTheme.border),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.radar,
                    size: 32,
                    color: WalkieTheme.textMuted,
                  ),
                  SizedBox(height: 8),
                  Text(
                    '正在搜索其他设备...',
                    style: TextStyle(
                      fontSize: 13,
                      color: WalkieTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberItem(_MemberItem member) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // 头像占位（首字母）
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: member.isSpeaking
                  ? WalkieTheme.accent.withValues(alpha: 0.15)
                  : WalkieTheme.surfaceElevated,
              border: Border.all(
                color: member.isSpeaking
                    ? WalkieTheme.accent.withValues(alpha: 0.5)
                    : WalkieTheme.border,
                width: member.isSpeaking ? 2 : 1,
              ),
            ),
            child: Center(
              child: Text(
                member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: member.isSpeaking
                      ? WalkieTheme.accent
                      : WalkieTheme.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 名字
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.isLocal ? '${member.name} (我)' : member.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: member.isSpeaking
                        ? WalkieTheme.accent
                        : WalkieTheme.textPrimary,
                  ),
                ),
                if (member.isSpeaking)
                  const Text(
                    '正在讲话',
                    style: TextStyle(
                      fontSize: 11,
                      color: WalkieTheme.accent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          // 信号质量指示器
          if (!member.isSpeaking)
            SignalIndicator(quality: member.signalQuality, size: 14),
          // 讲话指示器
          if (member.isSpeaking)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: WalkieTheme.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSoundBars(),
                  const SizedBox(width: 4),
                  const Text(
                    'LIVE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: WalkieTheme.accent,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildSoundBars() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        return Container(
          width: 3,
          height: 4 + i * 3.0,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: WalkieTheme.accent,
            borderRadius: BorderRadius.circular(1.5),
          ),
        );
      }),
    );
  }
}

class _MemberItem {
  final String name;
  final bool isLocal;
  final bool isOnline;
  final bool isSpeaking;
  final int signalQuality;

  _MemberItem({
    required this.name,
    required this.isLocal,
    required this.isOnline,
    required this.isSpeaking,
    this.signalQuality = 4,
  });
}
