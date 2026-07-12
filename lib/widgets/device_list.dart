import 'package:flutter/material.dart';
import 'package:jiudhiduijiang/theme/walkie_theme.dart';
import 'package:jiudhiduijiang/models/device.dart';

/// 紧凑型在线设备列表
class DeviceList extends StatelessWidget {
  final List<Device> devices;

  const DeviceList({super.key, required this.devices});

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: WalkieTheme.surfaceMid,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: WalkieTheme.border),
        ),
        child: Row(
          children: [
            Icon(Icons.radar, size: 16, color: WalkieTheme.ledAmber),
            const SizedBox(width: 8),
            Text(
              '正在搜索设备...',
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      decoration: BoxDecoration(
        color: WalkieTheme.surfaceMid,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: WalkieTheme.border),
      ),
      child: Column(
        children: [
          // 标题行
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.people_alt_outlined,
                    size: 14, color: WalkieTheme.textDim),
                const SizedBox(width: 6),
                Text(
                  'DEVICES (${devices.where((d) => d.isOnline).length})',
                  style: TextStyle(
                    fontFamily: WalkieTheme.fontMono,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: WalkieTheme.textDim,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: WalkieTheme.border),
          // 设备列表
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 120),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 2),
              itemCount: devices.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: WalkieTheme.surfaceLight),
              itemBuilder: (context, index) {
                final device = devices[index];
                return _buildDeviceItem(device);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceItem(Device device) {
    final online = device.isOnline;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // 在线状态指示点
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: online
                  ? WalkieTheme.ledGreen
                  : WalkieTheme.ledDim,
              boxShadow: online
                  ? [
                      BoxShadow(
                        color: WalkieTheme.ledGreen.withValues(alpha: 0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
          ),
          const SizedBox(width: 10),
          // 设备名称
          Expanded(
            child: Text(
              device.name,
              style: TextStyle(
                fontFamily: WalkieTheme.fontMono,
                fontSize: 12,
                color: online ? WalkieTheme.textPrimary : WalkieTheme.textDim,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // IP地址
          Text(
            device.address.address,
            style: TextStyle(
              fontFamily: WalkieTheme.fontMono,
              fontSize: 10,
              color: WalkieTheme.textDim,
            ),
          ),
        ],
      ),
    );
  }
}
